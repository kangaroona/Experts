//+------------------------------------------------------------------+
//|                                                    BBands_EA.mq4 |
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
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
input int      FisherPeriod=10;
input double   Lots = 0.1;
//input int haPeriod=3; 
input int SPREAD = 300;
input int Pips = 500;
input long restSecond = 20;
input double PSARStep = 0.02;                     // PSAR Step
input int BarPeriod = 20;                         //average bar depend on 
input double PSARMax = 0.2;                       // PSAR Max
input double percentOfSL = 2;
input int barNo = 2;
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
input int Bbands_len = 9;
input int Bbands_Deviation=2;
struct IndicatorFisher{
   double Weight1;
   double buyPrice;
   double sellPrice;
   double Weight2;
   double Weight3;
   double buySL;
   double sellSL;
   long restSecond;
   double SLBySAR;
   double barAverage;
   int OpenBarShift;
   double profitFromIdxDay;
   double Bbands_up;
   double Bbands_down;
   double Bbands_up_prev;
   double Bbands_down_prev;

};
IndicatorFisher ind1;
long prevBar;
long restTime;
#define COMMENT  "BBands_EA_20240110_"+IntegerToString(Timeframe) 
#define MAGICMA  01102143
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
void createLine(string name,double data,color colorValue){
   ObjectDelete("sellprice");
   ObjectDelete("buyprice");
   ObjectCreate(name,OBJ_HLINE,0,0,data);
   ObjectSet(name,OBJPROP_COLOR,colorValue);
}
double getLine(string name){
   return ObjectGetDouble(0,name,OBJPROP_PRICE,0);
}
void resetPrice(string flag){
   if(flag == "buyprice"){
         ind1.buyPrice = 0;
         ObjectDelete("buyprice");
   }
   if(flag =="sellprice"){
      ind1.sellPrice = 0;
   
      ObjectDelete("sellprice");
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

   ind1.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
   ind1.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
   ind1.Weight3 = NormalizeDouble((Low[3]+High[3]+Close[3]+Open[3])/4,Digits);
   ind1.SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
   ind1.barAverage = getAverageByPeriod(BarPeriod,ind1.barAverage);
   ind1.restSecond = PeriodSeconds(PERIOD_CURRENT) -(int)(TimeCurrent()-Time[0]);
   ind1.Bbands_up = NormalizeDouble(iCustom(NULL,Timeframe,"BBands_Stop_v1",9,2,1.00,1,1,1000,0,1),Digits);
   ind1.Bbands_down = NormalizeDouble(iCustom(NULL,Timeframe,"BBands_Stop_v1",9,2,1.00,1,1,1000,1,1),Digits);
   ind1.Bbands_up_prev = NormalizeDouble(iCustom(NULL,Timeframe,"BBands_Stop_v1",9,2,1.00,1,1,1000,0,2),Digits);
   ind1.Bbands_down_prev = NormalizeDouble(iCustom(NULL,Timeframe,"BBands_Stop_v1",9,2,1.00,1,1,1000,1,2),Digits);
   
}
void checkForOpen(){
   bool IsSucc = false;
   if((ind1.Bbands_down_prev>0 && ind1.Bbands_up_prev==-1) && (ind1.Bbands_down==-1 && ind1.Bbands_up>0)){
     // Print("prevdown:",ind1.Bbands_down_prev,",prevup:",ind1.Bbands_up_prev);
      open(OP_BUY,Ask,0,0,Blue);
   }
   if((ind1.Bbands_down_prev==-1 && ind1.Bbands_up_prev>0) && (ind1.Bbands_down>0 && ind1.Bbands_up==-1)){
      //Print("prevdown:",ind1.Bbands_down_prev,",prevup:",ind1.Bbands_up_prev);
      open(OP_SELL,Bid,0,0,Red);
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
bool isClose(int cmd){ //判断开盘后的前 barNo 的柱子是否符合预期（是否柱子的重心都在开盘价之上/下），保护开错单，能及早平
   if(ind1.OpenBarShift==barNo){
      for(int i=barNo;i>0;i--){
         double curWeight = NormalizeDouble((Low[i]+High[i]+Close[i]+Open[i])/4,Digits);
         if(cmd == OP_BUY && curWeight>OrderOpenPrice()){
            return false;
         }
         if(cmd == OP_SELL && curWeight<OrderOpenPrice()){
            return false;
         }
      }
      return true;
   }
   return false;

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
      if (ind1.SLBySAR==0)
   
     {

         Print("Not enough historical data - please load more candles for the selected timeframe.");

         return;

     }
     //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
      if ((OrderType() == OP_BUY)){
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
               if((newBuySL>SLPrice || SLPrice == 0) && (newBuySL <= Bid)){
                  //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),newBuySL,0,0,Blue);
                  //Print("Modify order",OrderTicket(),",Weight1:",ind1.Weight1,",Weight2:",ind1.Weight2,",Weight3:",ind1.Weight3,",SL:",newBuySL,",Low_index:",low_idx,",res:",res,",Bid:",Bid);
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
          if((ind1.Bbands_down_prev==-1 && ind1.Bbands_up_prev>0) && (ind1.Bbands_down>0 && ind1.Bbands_up==-1)){
               Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",up:",ind1.Bbands_down_prev,",down:",ind1.Bbands_down,",restSecond:",ind1.restSecond);
          }
          if(isClose(OP_BUY)){
           // Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
          } 
      }
      if((OrderType() == OP_SELL)){
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
               if((newSellSL<SLPrice || SLPrice == 0)  && (newSellSL > Ask)){//重心反转 ，设置止损
                   //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),newSellSL,0,0,Red);
                   //Print("Modify",OrderTicket(),"Weight1:",ind1.Weight1,",Weight2:",ind1.Weight2,",Weight3:",ind1.Weight3," SL:",newSellSL,",res:",res,", highIndex",high_idx,",Ask:",Ask);
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
         if((ind1.Bbands_down_prev>0 && ind1.Bbands_up_prev==-1) && (ind1.Bbands_down==-1 && ind1.Bbands_up>0)){
                Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",up:",ind1.Bbands_up,",down:",ind1.Bbands_down,",restSecond:",ind1.restSecond);
         }
         if(isClose(OP_SELL)){
            //Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
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
      CalcInd();
      checkForOpen();
      CheckForClose();
      checkProfitByDay(0);
      Comment("up:",ind1.Bbands_up,
      "\n down:",ind1.Bbands_down,
      "\n profit:",ind1.profitFromIdxDay,
      "\n restSecond:",ind1.restSecond
      );
      }
   
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
