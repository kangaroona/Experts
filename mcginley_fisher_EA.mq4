//+------------------------------------------------------------------+
//|                                           mcginley_fisher_EA.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
extern string Fisher="----------------Fisher----------------------";
input int      FisherPeriod=10;
input long restSecond = 20;
extern string Base="----------------Base----------------------";
input double   Lots = 0.1;
input int SPREAD = 300;
input int FailBarNo = 2;
enum DF{
   current=PERIOD_CURRENT,
   M1=PERIOD_M1,
   M5=PERIOD_M5,
   M15=PERIOD_M15,
   M30=PERIOD_M30,
   H1=PERIOD_H1,
   H4=PERIOD_H4,
   D1=PERIOD_D1
};
input DF Timeframe = M5; 
extern string PSAR="----------------SAR----------------------";
input double PSARStep = 0.02;                     // PSAR Step
input double PSARMax = 0.2;                       // PSAR Max
extern string AverageBar="----------------AverageBarForProfitSL----------------------";
input int BarPeriod = 20;                         //average bars
input double percentOfSL = 3;
extern string ATR="----------------ATR----------------------";
input double timesOfATR = 1;
input int ATRPeriod = 14;
extern string McGinLy="----------------McGinLey----------------------";
enum maMethod
{
   ma_sma,  // Simple moving average
   ma_ema,  // Exponential moving average
   ma_smma, // Smoothed moving average
   ma_lwma, // Linear weighted moving average
   ma_gen   // Generic moving average
};
extern maMethod           McgMaMethod = ma_lwma;       // Average mode
input int McgLowPeriod = 8;
input int McgHighPeriod = 8;
input int McgMedimPeriod = 3;
extern double             McgConstant = 5;          // Constant
struct IndicatorFisher{
   double fishVal;
   double fishPreVal;
   double Weight1;
   double buyPrice;
   double sellPrice;
   double Weight2;
   double Weight3;
   long restSecond;
   double SLBySAR;
   double barAverage;
   int OpenBarShift;
   double profitFromIdxDay;
   double AtrValue;
   double McgLowVal0;
   double McgLowVal1;
   double McgLowVal2;
   double McgHighVal0;
   double McgHighVal1;
   double McgHighVal2;
   double McgMedianVal0;
   string single;
   double McgMedianVal1;
   

};
IndicatorFisher ind1;
long prevBar;
long restTime;
#define COMMENT  "Mcg_Fisher_20240114_"+IntegerToString(Timeframe) 
#define MAGICMA  020114 //EANO+date
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   EventSetTimer(1);
   ObjectCreate(0,"lblTimer",OBJ_LABEL,0,NULL,NULL);
   ObjectSetString(0,"lblTimer",OBJPROP_TEXT,_Symbol+"蜡烛剩余");
   ObjectSetInteger(0,"lblTimer",OBJPROP_COLOR,clrGreen);
   ObjectSetInteger(0,"lblTimer",OBJPROP_CORNER ,CORNER_RIGHT_UPPER); 
   ObjectSetInteger(0,"lblTimer",OBJPROP_XDISTANCE,200);   
   ObjectSetInteger(0,"lblTimer",OBJPROP_YDISTANCE,40);
   ind1.buyPrice = 0;
   ind1.sellPrice = 0;
   ind1.barAverage = 0;
   ind1.single = "No Action";


//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ObjectsDeleteAll(0,0,OBJ_HLINE);
   EventKillTimer();
   ObjectsDeleteAll(0, 0, OBJ_LABEL);
   
   Print("EA运行结束，已经卸载" );
  }
bool open(int cmd,double price,double sl,double tf,color arrColor){
   if(getCurOrderCount()==0){ //当前trading池子里没有单子，才会开单
      //ind.single = cmd==OP_BUY?"buy":"sell";
      int res = OrderSend(Symbol(), cmd, Lots, price, 5,sl, tf,  COMMENT,MAGICMA,0,arrColor);
      if(res<0){
         Print("open fail");
         return false;
      }
         return true;  
   }
   return false;

}
bool isNewBar(){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      prevBar = curBar;
      return true;
   }
   return false;

}
void OnTimer()
{
   // 定时刷新计算当前蜡烛剩余时间
   long hour = Time[0] + 60 * Period() - TimeCurrent();
   long minute = (hour - hour % 60) / 60;
   long second = hour % 60;
   ObjectSetString(0,"lblTimer",OBJPROP_TEXT,StringFormat("%s蜡烛剩余：%d分%d秒",_Symbol,minute,second));
   restTime = minute*60+second;;
}
int getCurOrderCount(){
   int orderCount = 0;
   bool bo = false;
   for(int i=OrdersTotal()-1;i>=0;i--){
      bo= OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(!bo) continue;
      if(OrderSymbol()==Symbol() && OrderComment()==COMMENT){
         orderCount++;
         break;
      }
  
   }
   return orderCount;
}
bool isLatestCloseBar(){  //当前 bar 是否是最新的 closebar
   int latestCloseBarIdx = -1;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
         //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
         if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
         int curBarIdx = iBarShift(NULL,Timeframe,OrderCloseTime());
         if(curBarIdx==0)          latestCloseBarIdx=0;
         break;
      }
         
   }
   if(latestCloseBarIdx == 0) return true;
   return false;
}
void createLine(string name,double data,color colorValue,int width=1){
   ObjectDelete(name);
   //Print("liine:",data);
   ObjectCreate(name,OBJ_HLINE,0,0,data);
   ObjectSet(name,OBJPROP_COLOR,colorValue);
   ObjectSet(name, OBJPROP_WIDTH,width);
}
double getLine(string name){
   return ObjectGetDouble(0,name,OBJPROP_PRICE,0);
}
void resetPrice(string flag){
   ObjectDelete(flag);
   if(flag == "buyprice"){
         ind1.buyPrice = 0;
   }
   if(flag =="sellprice"){
      ind1.sellPrice = 0;
   }
         
         
}
bool checkTempLine(int lastedCloseIdx,double lowVal, double highVal){
   int i =0;
   for(i;i<lastedCloseIdx;i++){
      double curLowVal = Low[i];
      double curHighVal = High[i];
      if(curLowVal<lowVal || curHighVal>highVal) break;
   }
   if(i==lastedCloseIdx-1) return true;
   return false;
}
//连续两次失败，找到这区间的最大和最小值
void creatTempSupportLine(){
  int count = 0;
  double lowVal=0;
  double highVal = 0;
  int lastedCloseIdx = 0;
  for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
         if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
         if(OrderProfit()<0){
            int startBar = iBarShift(NULL,Timeframe,OrderOpenTime());
            int endBar = iBarShift(NULL,Timeframe,OrderCloseTime());
            if(count ==0) lastedCloseIdx = endBar;
            int curHighestIdx = iHighest(NULL,Timeframe,MODE_HIGH,startBar-endBar+1,endBar);
            int curLowestIdx = iLowest(NULL,Timeframe,MODE_LOW,startBar-endBar+1,endBar);
            if(endBar>20) break;//只计算 20 bar 以内的波动
            //Print("start:",startBar,",end:",endBar,"hignindex:",curHighestIdx,",lowIndex:",curLowestIdx,",ticket:",OrderTicket(),",OrderOpenTime:",OrderOpenTime());
            if(High[curHighestIdx]>highVal || highVal==0){
               highVal = High[curHighestIdx];
            }
            if(Low[curLowestIdx]<lowVal || lowVal==0){
               lowVal = Low[curLowestIdx];
            }
            count++;
            if(count==2) break;
         }
         else{
            break;
         }
      }
   }
   if(count == 2 && checkTempLine(lastedCloseIdx,lowVal,highVal)){// 如果距离上一次失败的 close bar 内没有突破最大最小值，则设置区间，反之，若是突破这个区间就不去设置了
      Print("high:",highVal,",low:",lowVal,",lastedCloseIdx:",lastedCloseIdx);
      createLine("highest",highVal,Green,2);
      createLine("lowest",lowVal,Plum,2);
      
   }
   else{
      resetPrice("highest");
      resetPrice("lowest");
   }
}
//period 周期里 bar 的平均值
double getAverageByPeriod(int period,double curAverage){
   if(isNewBar() || curAverage==0){
      double sum = 0;
      
      for(int i=1; i<=period; i++){
         sum+=High[i]-Low[i];
      }
      return NormalizeDouble(sum/period,Digits);
   }
   return curAverage;
}
void CalcInd(){

   ind1.fishVal = iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,0);
   ind1.fishPreVal = iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,1)==0?iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,1,1):iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,1);
   ind1.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
   ind1.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
   ind1.Weight3 = NormalizeDouble((Low[3]+High[3]+Close[3]+Open[3])/4,Digits);
   ind1.AtrValue = iATR(NULL,Timeframe,ATRPeriod,0);
   ind1.SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
   ind1.barAverage = getAverageByPeriod(BarPeriod,ind1.barAverage);
   ind1.restSecond = PeriodSeconds(PERIOD_CURRENT) -(int)(TimeCurrent()-Time[0]);
   ind1.McgLowVal0 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgLowPeriod,PRICE_LOW,McgConstant,McgMaMethod,0,0);
   ind1.McgLowVal1 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgLowPeriod,PRICE_LOW,McgConstant,McgMaMethod,0,1);
   ind1.McgLowVal2 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgLowPeriod,PRICE_LOW,McgConstant,McgMaMethod,0,2);
   
   ind1.McgHighVal0 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgHighPeriod,PRICE_HIGH,McgConstant,McgMaMethod,0,0);
   ind1.McgHighVal1 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgHighPeriod,PRICE_HIGH,McgConstant,McgMaMethod,0,1);
   ind1.McgHighVal2 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgHighPeriod,PRICE_HIGH,McgConstant,McgMaMethod,0,2);
   
   ind1.McgMedianVal0 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgMedimPeriod,PRICE_MEDIAN,McgConstant,McgMaMethod,0,0);
   ind1.McgMedianVal1 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgMedimPeriod,PRICE_MEDIAN,McgConstant,McgMaMethod,0,1);
   //ind1.McgMedimVal2 = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgMedimPeriod,PRICE_HIGH,McgConstant,McgMaMethod,0,2);
   ind1.single = "No action";
   
}
void CalSingle(){
 if(Close[1]>ind1.McgHighVal1 && Close[2]>ind1.McgHighVal2 && ind1.fishVal>0 && ind1.Weight1>ind1.Weight2){ //buy 的 signle：close 连续两根 bar 站上 mcghigh 且当前 fisher >0
   if(ind1.McgMedianVal0>=ind1.McgHighVal0 && ind1.McgMedianVal1<ind1.McgHighVal1){ //中线突破最高
      ind1.single = "buy";
   }
 }
 if(Close[1]<ind1.McgLowVal1 && Close[2]<ind1.McgLowVal2 && ind1.fishVal<0 && ind1.Weight1<ind1.Weight2){
   if(ind1.McgMedianVal0<=ind1.McgLowVal0 && ind1.McgMedianVal1>ind1.McgHighVal1){
      ind1.single = "sell";
   }
 }
}
void checkForOpen(){
   bool IsSucc = false;
   //Print("isLatestCloseBar",isLatestCloseBar());
   if(!isLatestCloseBar()){
      if(ind1.single=="buy"){ // buy
         IsSucc = open(OP_BUY,Ask,0,0,Blue);
   
      }
      if(ind1.single=="sell"){ //sell
         IsSucc = open(OP_SELL,Bid,0,0,Red);
      }
   }
}

double getBsByPercent(double percent){
    double res = 1;
    if(percent>0 && percent<0.25){
      res = 3;
    }
    else if(percent>=0.25 && percent<0.5){
      res = 2;
    }
    return res;
}
bool isClose(int cmd){ //判断开盘后的前 FailBarNo 的柱子是否符合预期（是否柱子的重心都在开盘价之上/下），保护开错单，能及早平
   bool isCloseFlag = false;
   if(ind1.OpenBarShift==FailBarNo){
      int count = 0;
      double baseWeight = NormalizeDouble((Low[FailBarNo]+High[FailBarNo]+Close[FailBarNo]+Open[FailBarNo])/4,Digits);
      for(int i=FailBarNo;i>0;i--){
         double curWeight = NormalizeDouble((Low[i]+High[i]+Close[i]+Open[i])/4,Digits);
         if(cmd == OP_BUY){
            if(i==FailBarNo && Open[FailBarNo]>Close[FailBarNo]){
               count++;
            }
            if(i<FailBarNo && curWeight<baseWeight){
               count++;
            }
         }
         if(cmd == OP_SELL){
            if(i<FailBarNo && curWeight>baseWeight){
               count++;
            }
            if(i==FailBarNo && Open[FailBarNo]<Close[FailBarNo]){
               count++;
            }
         }
      }
      if(count==FailBarNo){
         isCloseFlag = true;
      }
   }
   return isCloseFlag;

}
void TrailingPositions(){
   string Instrument = OrderSymbol();
   double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
   double SLPrice = NormalizeDouble(OrderStopLoss(), Digits);
   double curProfit = OrderProfit()+OrderSwap()-OrderCommission();
   double Spread = NormalizeDouble(SPREAD * MarketInfo(Instrument, MODE_POINT),Digits);
   ind1.OpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime()); //当前 bar 和开盘时候的 bar 相差几个 bar
   if (ind1.SLBySAR==0)
   {
   
         Print("Not enough historical data - please load more candles for the selected timeframe.");
   
         return;
   
   }
  //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
   if ((OrderType() == OP_BUY)){
       if(ind1.OpenBarShift==0 && ind1.fishVal<0){//如果开仓的 bar 的 fisher<0的话，意味着开错了，立即平仓
          Print("errorOpen 平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
       }
       double curSARSL = NormalizeDouble(ind1.SLBySAR-Spread,Digits);  
       if(curSARSL<Low[0]){//设置SAR止损.TODO:设置止损跟随
         if((curSARSL>SLPrice || SLPrice == 0) && curSARSL<Bid){
            if((Time[0]>OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)<Low[1])|| ind1.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
               bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSARSL,0,0,Blue);
               Print("Modify order:",OrderTicket(),",reason:SAR,PrevSL:",SLPrice,",SL:",curSARSL,",SAR:",curSARSL,",res:",res,",Bid:",Bid);
            }
         }
         
       }
       //else {//sar 不符合条件
            
         if((ind1.Weight1<ind1.Weight2 && ind1.Weight3<ind1.Weight2) && ind1.Weight1<ind1.Weight3 && ind1.OpenBarShift>=3){//出现地高低形态，设置最近 4 个 bar 最小值为 SL
            int low_idx = iLowest(NULL,Timeframe,MODE_LOW,3,1);
            double newBuySL = MathMin(NormalizeDouble(Low[low_idx],Digits),Bid);
            if((newBuySL>SLPrice || SLPrice == 0) && (newBuySL <= Bid)  && Open[0]<newBuySL){
               bool res = OrderModify(OrderTicket(),OrderOpenPrice(),newBuySL,0,0,Blue);
               Print("Modify order",OrderTicket(),",Weight1:",ind1.Weight1,",Weight2:",ind1.Weight2,",Weight3:",ind1.Weight3,",SL:",newBuySL,",fisher:",ind1.fishVal,",Low_index:",low_idx,",res:",res,",Bid:",Bid);
            }
         }
       //}
       if(Bid>OrderOpenPrice() && curProfit>0){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bar倍数来设置
          double diffPrice = MathAbs(NormalizeDouble(Bid-OrderOpenPrice(),Digits));
          double percent = NormalizeDouble((diffPrice/ind1.barAverage),Digits);

          if(diffPrice>ind1.barAverage && percent>=percentOfSL && ind1.Weight1<ind1.Weight2){ 
             double curSL =  NormalizeDouble((OrderOpenPrice()+diffPrice/3),Digits);    
             if(curSL>SLPrice && curSL<Bid){
                //createLine("SLline",curSL,Plum);
                bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Blue);
                Print("Modify",OrderTicket(),",reason:profit SL","percent:",percent," SL:",curSL,",res:",res,", bid:",Bid);
             }

          }
       }

   }
   if((OrderType() == OP_SELL)){
     if(ind1.OpenBarShift==0 && ind1.fishVal>0){ //检查是否开错单了
            Print("erroropen 平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
      }
      double curSARSL = NormalizeDouble(ind1.SLBySAR+Spread,Digits); 
      if((curSARSL>High[0])){//SAR 位置准确优先 Sar 设置     
         if((curSARSL<SLPrice || SLPrice==0) && Ask<curSARSL){
            if((Time[0]>OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)>High[1])|| ind1.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
               bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSARSL,0,0,Red);
               Print("Modify order:","reason:SAR",OrderTicket(),",PrevSL:",SLPrice,",SL:",curSARSL,",SAR:",ind1.SLBySAR,",res:",res,",Ask:",Ask);
            }
          }
      }
      //else{ // SAR 位置不对的话，再启用重心反转
         if(ind1.Weight1>ind1.Weight2 && ind1.Weight3>ind1.Weight2 && ind1.Weight1>ind1.Weight3 && ind1.OpenBarShift>=3){//SELL 条件是形成高低高的形态，按照最近4bar最大值设置止损
            int high_idx = iHighest(NULL,Timeframe,MODE_HIGH,3,1);
            double newSellSL = MathMax(NormalizeDouble(High[high_idx],Digits),Ask);
            if((newSellSL<SLPrice || SLPrice == 0)  && (newSellSL > Ask) &&  Open[0]>newSellSL){//重心反转 ，设置止损
                bool res = OrderModify(OrderTicket(),OrderOpenPrice(),newSellSL,0,0,Red);
                Print("Modify",OrderTicket(),"Weight1:",ind1.Weight1,",Weight2:",ind1.Weight2,",Weight3:",ind1.Weight3," SL:",newSellSL,"fisher:",ind1.fishVal,",res:",res,", highIndex",high_idx,",Ask:",Ask);
            }
         }
      //}

      if(Ask<OrderOpenPrice() && curProfit>0){

         double diffPrice = MathAbs(NormalizeDouble(OrderOpenPrice()-Ask,Digits));

         double percent = NormalizeDouble((diffPrice/ind1.barAverage),Digits);

          if(diffPrice>ind1.barAverage && percent>=percentOfSL && ind1.Weight1>ind1.Weight2){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bbar 的情况且暂时反转
             double curSL =  NormalizeDouble((OrderOpenPrice()- diffPrice/3),Digits);
                if(curSL<SLPrice && curSL>Ask){
                           //createLine("SLline",curSL,Plum);
                  bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Red);
                  Print("Modify",OrderTicket(),",reason:profit SL","percent:",percent," SL:",curSL,",res:",res,", Ask:",Ask);
                }

          }
       }
   }
}
void CheckForClose(){  
   for(int i=0;i<OrdersTotal();i++)
    {
      //如果 没有本系统所交易的仓单时，跳出循环
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      TrailingPositions();
      if(OrderType()==OP_BUY){
         if((ind1.fishVal<0 || ind1.McgMedianVal0<=ind1.McgLowVal0 || Open[0]<ind1.McgHighVal0) && ind1.restSecond<=restSecond){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",fishVal:",ind1.fishVal,",McgMedianVal0:",ind1.McgMedianVal0,",McgLowVal0:",ind1.McgLowVal0,",restSecond:",ind1.restSecond);
         }
         if(isClose(OP_BUY)){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",reason:weight<baseWeight");
         } 
      }
      if(OrderType()==OP_SELL){
         if((ind1.fishVal>0 || ind1.McgMedianVal0>=ind1.McgHighVal0 || Open[0]>ind1.McgLowVal0) && ind1.restSecond<=restSecond){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishVal:",ind1.fishVal,",McgMedianVal0:",ind1.McgMedianVal0,",McgHighVal0:",ind1.McgHighVal0,",restSecond:",ind1.restSecond);
         }
         if(isClose(OP_SELL)){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",reason:weight>baseWeight");
         } 
      }
    }

}
void checkProfitByDay(int indexDay){
   const datetime timeStart=iTime(_Symbol,PERIOD_D1,indexDay),
                  timeEnd = TimeCurrent();
   double result=0.;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
         //filter by OrderSymbol() and OrderMagicNumber() here
         if(OrderCloseTime()<timeStart || OrderCloseTime()>=timeEnd) continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
      }
   }
   for(int j=0;j<OrdersTotal();j++){
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderOpenTime()<timeStart) continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
   }
   ind1.profitFromIdxDay = NormalizeDouble(result,2);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    int vSpread  = (int)MarketInfo(Symbol(),MODE_SPREAD);
   //Print("Total windows = ", WindowsTotal(),",wid:",ChartWindowFind(0,"Fisher"));
    //Print("PERIOD_CURRENT:",Period(),",timeframe",(ENUM_TIMEFRAMES)Timeframe);
    if(Bars<100)
     {
      Print("bars less than 100");
      return;
     }
     if(vSpread<=SPREAD  && Period()==Timeframe){ //当前市场的点差小于设置的点差才进行计算
      RefreshRates();
      if(Volume[0]<=1){
         int fisherChartId = ChartWindowFind(0,"Fisher");
         WindowRedraw();
         Print("redraw succ");
         creatTempSupportLine();
      }
      CalcInd();
      CalSingle();
      checkForOpen();

      CheckForClose();

      checkProfitByDay(0);
      Comment("mcglow:",ind1.McgLowVal0,
      "\n mcghigh:",ind1.McgHighVal0,
      "\n average:",ind1.barAverage,
      "\n profit:",ind1.profitFromIdxDay,
      "\n restSecond:",ind1.restSecond,
      "\n rest",restTime
      );
      }
   
  }
//+------------------------------------------------------------------+
