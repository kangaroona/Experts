//+------------------------------------------------------------------+
//|                                                    Fisher_EA.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
extern string Fisher="----------------Fisher----------------------";
input int      FisherPeriod=10;
input long restSecond = 20;
extern string Base="----------------Base----------------------";
input double   Lots = 0.1;
//input int haPeriod=3; 
input int SPREAD = 300;
//input int Pips = 500;
input int FailBarNo = 2;
input long sleepSeconds = 30*60;
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
input DF Timeframe = M15; 
input int TEMAPeriod = 14;
input int haPeriod = 3;
input int pips = 1500;
input int tpPips = 2000;
extern string PSAR="----------------SAR----------------------";
input double PSARStep = 0.02;                     // PSAR Step
input double PSARMax = 0.2;                       // PSAR Max
extern string AverageBar="----------------AverageBarForProfitSL----------------------";
input int BarPeriod = 20;                         //average bars
input double percentOfSL = 2;
extern string ATR="----------------ATR----------------------";
input double timesOfATR = 1;
input int ATRPeriod = 14;
extern string McGinLy="----------------McGinLy----------------------";
enum maMethod
{
   ma_sma,  // Simple moving average
   ma_ema,  // Exponential moving average
   ma_smma, // Smoothed moving average
   ma_lwma, // Linear weighted moving average
   ma_gen   // Generic moving average
};
extern maMethod           McgMaMethod = ma_lwma;       // Average mode
input int McgPeriod = 8;
extern double             McgConstant = 5;          // Constant
struct IndicatorFisher{
   double fishVal;
   double fishPreVal;
   double Weight1;
   double buyPrice;
   double sellPrice;
   double Weight2;
   double Weight3;
   double zigZag;
   double fisher1;
   double fisher2;
   string fisherSignal;
   long restSecond;
   double SLBySAR;
   double barAverage;
   int OpenBarShift;
   double profitFromIdxDay;
   double AtrValue;
   double McgLowVal;
   double McgHighVal;
   double TemaPrev;
   int prevHeikenCountOfSell;
   int prevHeikenCountOfBuy;
   bool isNewBar;
   double avgOpenBar;
   

};
IndicatorFisher ind1;
long prevBar=0;
long restTime;
#define COMMENT  "Fisher_20240129_"+IntegerToString(Timeframe) 
#define MAGICMA  20240111
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
   //ind1.fisher1 = 0;
   //ind1.fisher2 = 0;
   ind1.buyPrice = 0;
   ind1.sellPrice = 0;
   ind1.barAverage = 0;
   ind1.prevHeikenCountOfBuy = 0;
   ind1.prevHeikenCountOfSell = 0;
   ind1.avgOpenBar = 0;

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
void setCountOfHeiken(){ //
   if(ind1.isNewBar){
      int prevBuyCount = 0;
      int prevSellCount = 0;
      string flagArr[2] = {"buy","sell"};
      for(int j=0;j<2;j++){
         for(int i=1;i<5;i++){
             double curHaOpen = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,0,i);
             double curHaClose = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,1,i);
             Print("flag=",flagArr[j]);
             if(flagArr[j]=="buy"){
                if(curHaClose>=curHaOpen){
                     prevBuyCount++;
                  }
                  else break;
             }
             if(flagArr[j]=="sell"){
               if(curHaClose<=curHaOpen){
                  prevSellCount++;
               }
               else break;
            }
      
         }
      }
      ind1.prevHeikenCountOfSell = prevSellCount;
      ind1.prevHeikenCountOfBuy = prevBuyCount;
   }

}
void OnTimer()
{
   // 定时刷新计算当前蜡烛剩余时间
   long hour = Time[0] + 60 * Period() - TimeCurrent();
   long minute = (hour - hour % 60) / 60;
   long second = hour % 60;
   ObjectSetString(0,"lblTimer",OBJPROP_TEXT,StringFormat("%s蜡烛剩余：%d分%d秒",_Symbol,minute,second));
   restTime = minute*60+second;;
  // ind1.restSecond = minute*60+second;
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
void createLine(string name,double data,color colorValue,int width=1){
   ObjectDelete(name);
   Print("liine:",data);
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
//连续两次失败，找到这区间的最大和最小值
void creatTempSupportLine(){
  int count = 0;
  double lowVal=0;
  double highVal = 0;
  for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
         if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
         if(OrderProfit()<0){
            int startBar = iBarShift(NULL,Timeframe,OrderOpenTime());
            int endBar = iBarShift(NULL,Timeframe,OrderCloseTime());
           
            int curHighestIdx = iHighest(NULL,Timeframe,MODE_HIGH,startBar-endBar+1,endBar);
            int curLowestIdx = iLowest(NULL,Timeframe,MODE_LOW,startBar-endBar+1,endBar);
            if(endBar>20) break;//只计算 20 bar 以内的波动
            Print("start:",startBar,",end:",endBar,"hignindex:",curHighestIdx,",lowIndex:",curLowestIdx,",ticket:",OrderTicket(),",OrderOpenTime:",OrderOpenTime());
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
   if(count == 2){
      Print("high:",highVal,",low:",lowVal);
      createLine("highest",highVal,Green,2);
      createLine("lowest",lowVal,Plum,2);
   }
   else{
      resetPrice("highest");
      resetPrice("lowest");
   }
   //createLine()
}
//period 周期里 bar 的平均值
double getAverageByPeriod(int period,double curAverage){
   if(ind1.isNewBar || curAverage==0){
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
   //ind1.fishVal = iCustom(NULL,Timeframe,"Fisherv2",Period,2,0);
   ind1.fishPreVal = iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,1)==0?iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,1,1):iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,1);
   //ind1.haOpen = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,0,1);
   //ind1.haClose = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,1,1);
   ind1.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
   ind1.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
   ind1.Weight3 = NormalizeDouble((Low[3]+High[3]+Close[3]+Open[3])/4,Digits);
   ind1.isNewBar = isNewBar();
   ind1.AtrValue = iATR(NULL,Timeframe,ATRPeriod,0);
   ind1.TemaPrev = iCustom(NULL,Timeframe,"TEMA",TEMAPeriod,0,1);
   ind1.zigZag = iCustom(NULL,Timeframe,"ZigZag",12,5,3,0,0);
   //Print("champion",iCustom(NULL,Timeframe,"CHAMPION Holy Grail",0,0));
   ind1.fisher1 = ind1.fishPreVal;
   ind1.fisherSignal = "NoAction";
   ind1.SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
   ind1.barAverage = getAverageByPeriod(BarPeriod,ind1.barAverage);
   ind1.restSecond = PeriodSeconds(PERIOD_CURRENT) -(int)(TimeCurrent()-Time[0]);
   ind1.McgLowVal = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgPeriod,PRICE_LOW,McgConstant,McgMaMethod,0,0);
   ind1.McgHighVal = iCustom(NULL,Timeframe,"mcginley dynamic 2.3",McgPeriod,PRICE_HIGH,McgConstant,McgMaMethod,0,0);
   if(ind1.fisher1>=0 && ind1.fisher2<0 && ind1.fisher2<ind1.fisher1){
      ind1.fisherSignal = "buy";
   }
   if(ind1.fisher1<=0 && ind1.fisher2>0 && ind1.fisher1<ind1.fisher2){
      ind1.fisherSignal = "sell";
   }
   //if(ind1.fisher1!=ind1.fisher2){
   //   Print("fisher1!=fisher2 fisher1:",ind1.fisher1,",fisher2:",ind1.fisher2,",restSecond:",ind1.restSecond,",signal:",ind1.fisherSignal);
   //}
   ind1.fisher2 = ind1.fisher1;
   setPriceLine();
   setCountOfHeiken();

}
void setTPLine(int cmd){
   string curLineName = "TPLINE";
   //Print(OrderTicket(),"=",OrderType());
   if(cmd==OP_BUY){
      if(Bid>=(OrderOpenPrice()+tpPips*Point)){
         if(Bid>getLine(curLineName)){
            createLine(curLineName,Bid,Yellow);
         }
      }
   }
   if(cmd == OP_SELL){
      if(Ask<=(OrderOpenPrice()-tpPips*Point)){
         if(Ask<getLine(curLineName) || getLine(curLineName)==0){
            createLine(curLineName,Ask,Yellow);
         }
      }
   }
   
}

void setPriceLine(){
   if(ind1.fishPreVal<=0){
      if(ind1.fishVal>0 && ind1.restSecond<=restSecond && getCurOrderCount()==0){ //buy
         //double curBuyPrice = High[1]+Pips*Point;
         double curBuyPrice = NormalizeDouble(High[1]+ind1.AtrValue*timesOfATR,Digits);
         if( getLine("buyprice")!=curBuyPrice){
            ind1.buyPrice = curBuyPrice;
            Print("draw buyprice",ind1.buyPrice,",prev:",getLine("buyprice"),",high:",High[1],",last second:",ind1.restSecond,",rest:",ind1.restSecond);
            resetPrice("sellprice");
            createLine("buyprice",ind1.buyPrice,Blue);
            
         }
      }
      else{
         if(getLine("buyprice")!=0 && ind1.fishVal<=0){
            Print("buyprice fishVal:",ind1.fishVal,",fishPrev: ",ind1.fishPreVal,",last second: ",ind1.restSecond);
            resetPrice("buyprice");
         }
      }

   }
   if(ind1.fishPreVal>=0){
      if(ind1.fishVal<0 && ind1.restSecond<=restSecond && getCurOrderCount()==0 && ind1.restSecond!=0){ //sell
         //double curSellPrice = Low[1]-Pips*Point;
         double curSellPrice = NormalizeDouble(Low[1]-ind1.AtrValue*timesOfATR,Digits);
         if(getLine("sellprice")!=curSellPrice){
            ind1.sellPrice = curSellPrice;
            Print("draw sellPrice",ind1.sellPrice,",prev:",getLine("sellprice")," ,Price:",Low[1],",last second",ind1.restSecond,"rest:",ind1.restSecond);
            resetPrice("buyprice");
            createLine("sellprice",ind1.sellPrice,Red);

         }
      }
      else{
         if(getLine("sellprice")!=0 && ind1.fishVal>0){
            Print("sellPrice fishVal:",ind1.fishVal,"fishPrev: ",ind1.fishPreVal,",last second: ",ind1.restSecond);
            resetPrice("sellprice");
         }
      }
   }
}
int getFisherCountByFlag(string flag){
   int count = 0;
   for(int i=1;i<5;i++){
      double curFisher =  iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,i)==0?iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,1,i):iCustom(NULL,Timeframe,"Fisherv2",FisherPeriod,0,i);
      if(flag == "buy"){
         if(curFisher>0){
            count++;
        }
        else break;
      }
      else if(flag == "sell"){
         if(curFisher<0){
            count++;
         }
      }
      else break;
   
   }
   return count;
}
void checkForOpen(){
   bool IsSucc = false;
   
   if(/*ind1.buyPrice!=0 && */ind1.fishVal>0 && Close[1]>ind1.TemaPrev /* Ask>=ind1.buyPrice*/){ // buy;
      if((ind1.prevHeikenCountOfBuy>=1 && ind1.prevHeikenCountOfBuy<=3)){//当前 bar前面的 heiken 值[1,4)
         IsSucc = open(OP_BUY,Ask,0,0,Blue);
         if(IsSucc){ //open 成功就 reset buyprice
            ind1.buyPrice = 0;
            ObjectDelete("buyprice");
            ObjectDelete("TPLINE");
         }
      }

   }
   if(/*ind1.sellPrice!=0 && */ind1.fishVal<0 && Close[1]<ind1.TemaPrev /*Bid<=ind1.sellPrice*/){ //sell
      if(ind1.prevHeikenCountOfSell>=1 && ind1.prevHeikenCountOfSell<=3){
         IsSucc = open(OP_SELL,Bid,0,0,Red);
         if(IsSucc){
            ind1.sellPrice = 0;
            ObjectDelete("sellprice");
            ObjectDelete("TPLINE");
         }
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
double getAverageByOpenBar(int openBar){
      if (openBar == 0){
         return 0;
      }
      if(ind1.isNewBar || ind1.avgOpenBar==0){
         double sum = 0;
         Print("openBar=",openBar);
         for(int i=1; i<=openBar; i++){
            sum+=MathAbs(Close[i]-Open[i]);
         }
         
         return NormalizeDouble(sum/openBar,Digits);
      }
      return ind1.avgOpenBar;
      
   
}
void CheckForClose(){

   
      
   for(int i=0;i<OrdersTotal();i++)
    {
      //如果 没有本系统所交易的仓单时，跳出循环
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      string Instrument = OrderSymbol();
      //Print("Symbol",Instrument);
      double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
      double SLPrice = NormalizeDouble(OrderStopLoss(), Digits);
      double curProfit = OrderProfit()+OrderSwap()-OrderCommission();
      double preClassicPrice = NormalizeDouble((Low[1]+High[1]+Close[1])/3,Digits);
      double Spread = NormalizeDouble(SPREAD * MarketInfo(Instrument, MODE_POINT),Digits);
      ind1.OpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime()); //当前 bar 和开盘时候的 bar 相差几个 bar
      ind1.avgOpenBar = getAverageByOpenBar(ind1.OpenBarShift);
      double heiKinClose1 = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,1,1);
      double heiKinClose2 = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,1,2);
      setTPLine(OrderType());
      if (ind1.SLBySAR==0)
   
     {

         Print("Not enough historical data - please load more candles for the selected timeframe.");

         return;

     }
     //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
      if ((OrderType() == OP_BUY)){
          //if(ind1.OpenBarShift==0 && ind1.fishVal<0){//如果开仓的 bar 的 fisher<0的话，意味着开错了，立即平仓
          //   Print("errorOpen 平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
          //}
          double curSARSL = NormalizeDouble(ind1.SLBySAR-Spread,Digits);  
          //Print(OrderSymbol(),"=",curSARSL);
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
          if((ind1.OpenBarShift>=2 && heiKinClose2>pips*Point+heiKinClose1 && MathAbs(Open[1]-Close[1])>ind1.avgOpenBar)){
               if((ind1.OpenBarShift==1 && curProfit>0) || ind1.OpenBarShift>1){
                  Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
               }
          }
          if(isClose(OP_BUY)){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",reason:weight<baseWeight");
          } 
      }
      if((OrderType() == OP_SELL)){
        //if(ind1.OpenBarShift==0 && ind1.fishVal>0){ //检查是否开错单了
        //       Print("erroropen 平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
        // }
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
         if((ind1.OpenBarShift>=2 && heiKinClose1>(heiKinClose2+pips*Point) && MathAbs(Open[1]-Close[1])>ind1.avgOpenBar)){
                if((ind1.OpenBarShift==1 && curProfit>0) || ind1.OpenBarShift>1){
                  Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",fishprev:",ind1.fishPreVal,",fishVal:",ind1.fishVal,",restSecond:",ind1.restSecond);
                }
         }
         if(isClose(OP_SELL)){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",reason:weight>baseWeight");
          } 
      }
    }

}
void calHeiKinReverse(){
//   if(ind1.isNewBar && ind1.OpenBarShift>=2){
//      int count = 0;
//      double preHeiKinClose=0;
//      for(int i=1;i<4;i++){
//         double curHeiKinClose = iCustom(NULL,Timeframe,"Heikin Ashi Lines",haPeriod,1,i);
//         if(i==1){
//            double heiKinClose1 = curHeiKinClose;
//         }
//         if(preHeikinClose==0){
//            preHeiKinClose = curHeiKinClose;
//            continue;
//         }
//         if(curHeiKinClose<preHeiKinClose){
//            count++;
//         }
//         else{
//            if(curHeiKinClose-heiKinClose1>ind1.a)
//         }
//         if(count)
//         
//         
//      }
//   }
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
      checkForOpen();
      CheckForClose();
      checkProfitByDay(0);
      Comment("HeikenCountOfBuy:",ind1.prevHeikenCountOfBuy,
      "\n HeikenCountOfSell:",ind1.prevHeikenCountOfSell,
      "\n average:",ind1.avgOpenBar,
      "\n profit:",ind1.profitFromIdxDay,
      "\n restSecond:",ind1.restSecond,
      "\n rest",restTime
      );
      }
   
  }
//+------------------------------------------------------------------+
