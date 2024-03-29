//+------------------------------------------------------------------+
//|                                                       EMA_EA.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include <EMA_util.mqh>
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
input int TPPips = 2000;
input double TPPercent = 0.8;

extern string EMA="----------------Trend_EMA----------------------";
extern ENUM_MA_METHOD           EMAMethod = MODE_EMA; 
extern ENUM_APPLIED_PRICE EMAPrice    = PRICE_CLOSE; 
input int EMA1 = 10;
input int EMA2 = 20;
input int EMA3 = 40;
input int EMA4 = 60;
extern string Entry_EMA="----------------Entry_EMA----------------------";
input int EMA5 = 5;
input int EMA6 = 10;
extern string PSAR="----------------SAR----------------------";
input double PSARStep = 0.02;                     // PSAR Step
input double PSARMax = 0.2;                       // PSAR Max
extern string AverageBar="----------------AverageBarForProfitSL----------------------";
input int BarPeriod = 20;                         //average bars
input double percentOfSL = 2;
extern string BBand="----------------BBand----------------------";
input int Bbands_Period = 9;
input int Bbands_Deviation=1;
input int Bbands_Deviation_SL = 2;
extern string Loss="----------------Loss----------------------";
input bool isOpenAutoClose = true;
input double LossPerDay = 100;
input bool IsSleepForLoss = true;
input int SleepMinutes = 30;
input int LossCount = 2;

struct IndicatorEMA{
   double emaArr[4][3];
   double Ema5_1;
   double Ema6_1;
   double Ema5_2;
   double Ema6_2;
   bool isNewBar;
   int emaSignal;
   double Bbands1_up;
   double Bbands1_down;
   double Bbands1_middle;
   double barAverage;
   int OpenBarShift;
   double Weight1;
   double Weight2;
   double profitFromIdxDay;
   bool shoudOpen;
   long duration;
   int prevEMACountOfSell;
   int prevEMACountOfBuy;
   int endIdx;
   double latestFailHigh;
   double latestFailLow;
   
   
};
IndicatorEMA ind;
int emaperiod[];
long prevBar=0;
string TPLineName = "TPLINE";
bool isDrawArrow = true;
#define COMMENT  "EMA_20240130_"+IntegerToString(Timeframe) 
#define MAGICMA  20240301
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   ChartSetSymbolPeriod(0,NULL,(int)Timeframe);
   ind.isNewBar = true;
   for(int i =0;i<4;i++){
      for(int j=0;j<3;j++){
         ind.emaArr[i][j] = 0;
      }
   }
   ArrayResize(emaperiod,4);
   emaperiod[0] = EMA1;
   emaperiod[1] = EMA2;
   emaperiod[2] = EMA3;
   emaperiod[3] = EMA4;
   ind.prevEMACountOfSell = 0;
   ind.prevEMACountOfSell = 0;
   ind.shoudOpen = true;
   calSleepTime();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   ObjectsDeleteAll(0,0,OBJ_HLINE);
   
   Print("EA运行结束，已经卸载" );
   ChartSetSymbolPeriod(0,NULL,(int)Timeframe);
  }
bool isNewBar(){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      prevBar = curBar;
      return true;
   }
   return false;

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
//void createLine(string name,double data,color colorValue,int width=1){
//   ObjectDelete(name);
//   ObjectCreate(name,OBJ_HLINE,0,0,data);
//   ObjectSet(name,OBJPROP_COLOR,colorValue);
//   ObjectSet(name, OBJPROP_WIDTH,width);
//}
double getLine(string name){
   return ObjectGetDouble(0,name,OBJPROP_PRICE,0);
}
void resetPrice(string flag){
   ObjectDelete(flag); 
   if(flag == "highest"){
      ind.latestFailHigh = 0;
   }
   if(flag == "lowest"){
      ind.latestFailLow = 0;
   } 
         
}
void ChangeArrowEmptyPoint(datetime &time,double &price)
  {
//--- if the point's time is not set, it will be on the current bar
   if(!time)
      time=TimeCurrent();
//--- if the point's price is not set, it will have Bid value
   if(!price)
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
  }
bool ArrowCreate(const long              chart_ID=0,           // chart's ID
                     const string            name="ArrowDown",     // sign name
                     const int               sub_window=0,         // subwindow index
                     datetime                time=0,               // anchor point time
                     double                  price=0,              // anchor point price
                     const ENUM_ARROW_ANCHOR anchor=ANCHOR_BOTTOM, // anchor type
                     const color             clr=clrRed           // sign color
                     )            // priority for mouse click
  {
//--- set anchor point coordinates if they are not set
   if(ObjectGetDouble(0,name,OBJPROP_PRICE,0)!=0) return false; 
   ObjectDelete(chart_ID,name);
   ChangeArrowEmptyPoint(time,price);
//--- reset the error value
   ResetLastError();
//--- create the sign
   if(!ObjectCreate(chart_ID,name,OBJ_ARROW_DOWN,sub_window,time,price))
     {
      Print(__FUNCTION__,
            ": failed to create \"Arrow Down\" sign! Error code = ",GetLastError());
      return(false);
     }
//--- anchor type
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set a sign color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set the border line style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,STYLE_SOLID);
//--- set the sign size
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,2);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,false);
//--- enable (true) or disable (false) the mode of moving the sign by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
 //  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,true);
 //  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,true);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,true);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,0);
//--- successful execution
   return(true);
  }
double getAverageByPeriod(int period,double curAverage){
   if(ind.isNewBar || curAverage==0){
      double sum = 0;
      
      for(int i=1; i<=period; i++){
         sum+=High[i]-Low[i];
      }
      return NormalizeDouble(sum/period,Digits);
   }
   return curAverage;
}
void CalcInd(){
   ind.isNewBar = isNewBar();
   ind.barAverage = getAverageByPeriod(BarPeriod,ind.barAverage);
   if(ind.isNewBar){
      int curEmaSignal = 0;
      ind.emaSignal = 0;
      //Print("emaperiod=",ArraySize(emaperiod));
      for(int i=0;i<ArraySize(emaperiod);i++){
         for(int j=0;j<3;j++){
            ind.emaArr[i][j] = NormalizeDouble(iMA(NULL,Timeframe,emaperiod[i],0,EMAMethod,EMAPrice,j+1),Digits);
         }
      }
      int zeroCount = 0;
      for(int k=0;k<ArraySize(emaperiod);k++){
         double EMA1OfPeriod = ind.emaArr[k][0];
         double EMA2OfPeriod = ind.emaArr[k][1];
         if(EMA1OfPeriod>EMA2OfPeriod){
            curEmaSignal++;
         }
         if(EMA1OfPeriod<EMA2OfPeriod){
            curEmaSignal--;
         }
         if(EMA1OfPeriod == EMA2OfPeriod){
            zeroCount++;
         }
      }
     // Print("zeroCount=",zeroCount,",curEmaSignal=",curEmaSignal);
      if(zeroCount<2){
         if(curEmaSignal>=2) ind.emaSignal = 1;
         if(curEmaSignal<=-2) ind.emaSignal = -1;
      } 
      ind.Ema5_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema6_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema5_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,2),Digits);
      ind.Ema6_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,2),Digits);
      ind.Bbands1_up = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_UPPER,1),Digits);
      ind.Bbands1_down = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_LOWER,1),Digits);
      ind.Bbands1_middle = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,1),Digits);
      ind.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
      ind.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
      setCountOfEMA();
      calSleepTime();
      creatTempSupportLine();
   }
}

void checkForOpen(){
   bool IsSucc = false;
   string curArrowName = TimeToStr(Time[0]);
   if(/*(Close[1]>ind.Bbands1_down && Close[1]<ind.Bbands1_up) &&*/ !isLatestCloseBar()){
      if(ind.emaSignal == 1 && (ind.Ema5_1>ind.Ema6_1 && Close[1]>ind.Ema5_1) && (ind.Ema5_1>ind.Ema5_2 && ind.Ema6_1>ind.Ema6_2) && ind.prevEMACountOfBuy>=1 && ind.prevEMACountOfBuy<=3){ // buy：快线大于慢线，且必须是上涨趋势 [1,3]
         if((ind.latestFailHigh!=0 && Bid>ind.latestFailHigh) || ind.latestFailHigh==0/* && ind.shoudOpen*/){
            IsSucc = open(OP_BUY,Ask,0,0,Blue);
            if(IsSucc){ //open 成功就 reset buyprice
               ObjectDelete(TPLineName);
            }
         }
         if(ind.latestFailHigh!=0 && Bid<ind.latestFailHigh){
            ArrowCreate(0,"ArrowUp"+curArrowName,0,TimeCurrent(),Open[0],ANCHOR_TOP,clrBlue);
         }    
      }
      if(ind.emaSignal == -1 && (ind.Ema5_1<ind.Ema6_1 && Close[1]<ind.Ema5_1)  && (ind.Ema5_1<ind.Ema5_2 && ind.Ema6_1<ind.Ema6_2)  && ind.prevEMACountOfSell>=1 && ind.prevEMACountOfSell<=3){ //sell
         if((ind.latestFailLow!=0 && Ask<ind.latestFailLow)  || ind.latestFailLow==0 /*ind.shoudOpen*/){
            IsSucc = open(OP_SELL,Bid,0,0,Red);
            if(IsSucc){
               ObjectDelete(TPLineName);
            }
         }
         if(ind.latestFailLow!=0 && Ask>ind.latestFailLow){
            ArrowCreate(0,"ArrowBottom"+curArrowName,0,TimeCurrent(),Open[0],ANCHOR_BOTTOM,clrRed);
         }
      }
   }
  
}
void setCountOfEMA(){ //
   int prevBuyCount = 0;
   int prevSellCount = 0;
   string flagArr[2] = {"buy","sell"};
   for(int j=0;j<2;j++){
      for(int i=1;i<5;i++){
          double fast =  NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,i),Digits);
          double slow =  NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,i),Digits);
          //Print(flagArr[j],",fast=",fast,",slow=",slow);
          if(flagArr[j]=="buy"){
             if(fast>=slow){
                  prevBuyCount++;
               }
               else break;
          }
          if(flagArr[j]=="sell"){
            if(fast<=slow){
               prevSellCount++;
            }
            else break;
         }
   
      }
   }
   ind.prevEMACountOfSell = prevSellCount;
   ind.prevEMACountOfBuy = prevBuyCount;


}
void setTPLine(int cmd){
   if(cmd==OP_BUY){
      if(Bid>=(OrderOpenPrice()+TPPips*Point)){
         if(Bid>getLine(TPLineName)){
            createLine(TPLineName,Bid,Yellow);
         }
      }
   }
   if(cmd == OP_SELL){
     // Print("line:",(OrderOpenPrice()-TPPips*Point));
      if(Ask<=(OrderOpenPrice()-TPPips*Point))
      {
         if(Ask<getLine(TPLineName) || getLine(TPLineName)==0){
            createLine(TPLineName,Ask,Yellow);
         }
      }
   }
   
}
void TrailingPositions(){
   string Instrument = OrderSymbol();
   double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
   double SLPrice = NormalizeDouble(OrderStopLoss(), Digits);
   double curProfit = OrderProfit()+OrderSwap()-OrderCommission();
   double Spread = NormalizeDouble(SPREAD * MarketInfo(Instrument, MODE_POINT),Digits);
   ind.OpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime()); //当前 bar 和开盘时候的 bar 相差几个 bar
   double SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
   setTPLine(OrderType());
   double curTP = getLine(TPLineName);
   double curBbands_up = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation_SL,0,EMAPrice,MODE_UPPER,0),Digits);
   double curBbands_down = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation_SL,0,EMAPrice,MODE_LOWER,0),Digits);
  // double Bbands1_middle = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,1),Digits);
   if (SLBySAR==0)
   {
   
         Print("Not enough historical data - please load more candles for the selected timeframe.");
   
         return;
   
   }
  //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
   if ((OrderType() == OP_BUY)){
       double curSLPrice = 0;
       string curSLReason = "";
       double curSARSL = NormalizeDouble(SLBySAR-Spread,Digits);  
       if(curSARSL<Low[0]){//设置SAR止损.TODO:设置止损跟随
         if((curSARSL>SLPrice || SLPrice == 0) && curSARSL<Bid){
            if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)<Low[1])|| ind.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
               curSLPrice = curSARSL;
               curSLReason = "SAR";
            }
         }
         
       }
      if((curBbands_down>curSLPrice || curSLPrice == 0) && curBbands_down<Bid){
         curSLPrice = curBbands_down;
         curSLReason = "BB";
      }
       if(Bid>OrderOpenPrice() && curProfit>0){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bar倍数来设置
          double diffPrice = MathAbs(NormalizeDouble(Bid-OrderOpenPrice(),Digits));
          double percent = NormalizeDouble((diffPrice/ind.barAverage),Digits);

          if(diffPrice>ind.barAverage && percent>=percentOfSL && ind.Weight1<ind.Weight2){ 
             double curSL =  NormalizeDouble((OrderOpenPrice()+diffPrice/3),Digits);    
             if(curSL>curSLPrice && curSL<Bid){
                //createLine("SLline",curSL,Plum);
                curSLPrice = curSL;
                curSLReason = "profit SL";
             }

          }
       }
       if(curTP>OrderOpenPrice()){
         double curTPLineSL = NormalizeDouble(OrderOpenPrice()+(curTP-OrderOpenPrice())*TPPercent,Digits);
         if(ind.Weight1<ind.Weight2 && Open[1]>Close[1]){//重心下降且是阴柱
            curTPLineSL = NormalizeDouble(OrderOpenPrice()+MathAbs((curTP-OrderOpenPrice()))*(1-TPPercent),Digits);
         }
         if(curTPLineSL>curSLPrice && curTPLineSL<Bid){
            curSLPrice = curTPLineSL;
            curSLReason = "TPLINE SL";
         }
       }
       if(curSLPrice>SLPrice || SLPrice==0){
         bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Blue);
         Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", bid:",Bid);
       }
       

   }
   if((OrderType() == OP_SELL)){
      double curSLPrice = 0;
      string curSLReason = "";
      double curSARSL = NormalizeDouble(SLBySAR+Spread,Digits); 
      if((curSARSL>High[0])){//SAR 位置准确优先 Sar 设置     
         if((curSARSL<SLPrice || SLPrice==0) && Ask<curSARSL){
            if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)>High[1])|| ind.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
               curSLPrice = curSARSL;
               curSLReason = "SAR";
               //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSARSL,0,0,Red);
               //Print("Modify order:","reason:SAR",OrderTicket(),",PrevSL:",SLPrice,",SL:",curSARSL,",SAR:",SLBySAR,",res:",res,",Ask:",Ask);
            }
          }
      }
      if((curBbands_up<curSLPrice || curSLPrice == 0) && curBbands_up>Ask){
         curSLPrice = curBbands_up;
         curSLReason = "BB";
         //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curBbands_up,0,0,Blue);
         //Print("Modify order:",OrderTicket(),",reason:BB,SL:",curBbands_up,",SL:",SLPrice);
      }
       
      if(Ask<OrderOpenPrice() && curProfit>0){

         double diffPrice = MathAbs(NormalizeDouble(OrderOpenPrice()-Ask,Digits));

         double percent = NormalizeDouble((diffPrice/ind.barAverage),Digits);

          if(diffPrice>ind.barAverage && percent>=percentOfSL && ind.Weight1>ind.Weight2){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bbar 的情况且暂时反转
             double curSL =  NormalizeDouble((OrderOpenPrice()- diffPrice/3),Digits);
                if((curSL<curSLPrice || curSLPrice == 0) && curSL>Ask){
                           //createLine("SLline",curSL,Plum);
                  curSLPrice = curSL;
                  curSLReason = "profit SL";
                  //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Red);
                  //Print("Modify",OrderTicket(),",reason:profit SL","percent:",percent," SL:",curSL,",res:",res,", Ask:",Ask);
                }

          }
       }
       if((curTP<OrderOpenPrice()&& curTP>0) && ind.OpenBarShift>=1){
         double curTPLineSL = NormalizeDouble(OrderOpenPrice()-MathAbs((curTP-OrderOpenPrice()))*TPPercent,Digits);
         if(ind.Weight1>ind.Weight2 && Open[1]<Close[1]){//重心升高，则如果>ASK 设置止损，否则直接按照现价平仓
            curTPLineSL = NormalizeDouble(OrderOpenPrice()-MathAbs((curTP-OrderOpenPrice()))*0.8,Digits);
         }
         if((curTPLineSL<curSLPrice || curSLPrice==0)&& curTPLineSL>Ask){
             curSLPrice = curTPLineSL;
             curSLReason = "TPLine SL";
             //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curTPLineSL,0,0,Blue);
             //Print("Modify",OrderTicket(),",reason:TPLine SL"," SL:",curTPLineSL,",res:",res,", bid:",Bid);
         }
       }
       if((curSLPrice<SLPrice || SLPrice==0) && curSLPrice>Ask){
         bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Red);
         Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", Ask:",Ask);
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
      double curTP = getLine(TPLineName);
      if(isOpenAutoClose&& ind.profitFromIdxDay<0 && MathAbs(ind.profitFromIdxDay)>=MathAbs(LossPerDay)){
         if(OrderType()==OP_BUY){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",reson:outofLossRange,spead:");
         }
         if(OrderType()==OP_SELL){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",reson:outofLossRange");
         }
      }
      if(OrderType()==OP_BUY){
        if(ind.Ema5_1<ind.Ema6_1 && ind.Ema5_1<ind.Ema5_2 && ind.Ema6_1<ind.Ema6_2 && Close[1]<ind.Ema5_1){
            Print("should close",OrderTicket(),",EM5=",ind.Ema5_1,",EMA6=",ind.Ema6_1);
            //Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",EM5=",ind.Ema5_1,",EMA6=",ind.Ema6_1);
        }
        if(ind.Weight1<ind.Weight2 && (curTP>OrderOpenPrice() && (MathAbs(curTP-Low[1])/MathAbs(curTP-OrderOpenPrice()))<(1-TPPercent)) && Open[1]>Close[1]){
          Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue),",percent:",(MathAbs(High[1]-Low[1])/MathAbs(curTP-OrderOpenPrice())));
        }
      }
      if(OrderType()==OP_SELL){
         if(ind.Ema5_1>ind.Ema6_1 && ind.Ema5_1>ind.Ema5_2 && ind.Ema6_1>ind.Ema6_2 && Close[1]>ind.Ema5_1){
            Print("should close",OrderTicket(),",EM5=",ind.Ema5_1,",EMA6=",ind.Ema6_1);
            //Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",EM5=",ind.Ema5_1,",EMA6=",ind.Ema6_1);
        }
        if(ind.Weight1>ind.Weight2 && (curTP<OrderOpenPrice() &&  curTP>0 && (MathAbs(curTP-High[1])/MathAbs(curTP-OrderOpenPrice()))<(1-TPPercent)) && Open[1]<Close[1]){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red),",Percent:",(MathAbs(curTP-High[1])/MathAbs(curTP-OrderOpenPrice())));
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
   ind.profitFromIdxDay = NormalizeDouble(result,2);
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
void calSleepTime(){
   int count = 0;
   ind.shoudOpen = true;
   datetime lastCloseTime=TimeCurrent();
   if(IsSleepForLoss){//设置开关则开始计算 shouldOPen
      for(int i=OrdersHistoryTotal()-1;i>=0;i--){
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
         //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
            if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
            if(OrderProfit()>=0) break;
            if(count==0) lastCloseTime = OrderCloseTime();
            count++;
            if(count==LossCount && TimeCurrent()>lastCloseTime){ //（连续 loss 的 bar 的个数达标）
               //Print("duration:",(int)(TimeCurrent()-lastCloseTime));
               ind.duration = (int)(TimeCurrent()-lastCloseTime);
               if((int)(TimeCurrent()-lastCloseTime)<=SleepMinutes*60)  ind.shoudOpen = false; //时间达标
               break;
            }
         }
            
      }
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
            if(count == 0){
               ind.endIdx = endBar;
            }
            int curHighestIdx = iHighest(NULL,Timeframe,MODE_HIGH,startBar-endBar+1,endBar);
            int curLowestIdx = iLowest(NULL,Timeframe,MODE_LOW,startBar-endBar+1,endBar);
            if(count==1  && ((Low[curLowestIdx]>highVal && highVal!=0) || (High[curHighestIdx]<lowVal && lowVal!=0))) break;
            //if(endBar>20) break;//只计算 20 bar 以内的波动
            //Print("start:",startBar,",end:",endBar,"hignindex:",curHighestIdx,",lowIndex:",curLowestIdx,",ticket:",OrderTicket(),",OrderOpenTime:",OrderOpenTime());
            if((High[curHighestIdx]>highVal) || highVal==0){
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
   if(count == 2){// 连续两次失败
      ind.latestFailHigh = highVal;
      ind.latestFailLow = lowVal;
      //createLine("highest",highVal,Green,2);
      //createLine("lowest",lowVal,Plum,2);
      if(!resetHighLine()){ //当前 bar 到最后一个失败 bar 之间是否 有超越 range 的
         createLine("highest",highVal,Green,2);
         createLine("lowest",lowVal,Plum,2);
      }
      else{
            Print("reset");
            resetPrice("highest");
            resetPrice("lowest");
         
      }
      
   }
   else{   
      resetPrice("highest");
      resetPrice("lowest");
   }
}
bool resetHighLine(){
   if(ind.endIdx<=1) return false;
   bool isReset = false;
   if(ind.latestFailHigh !=0 && ind.latestFailLow!=0){
      for(int i=1;i<=ind.endIdx+1;i++){
         if(Low[i]>ind.latestFailHigh || High[i]< ind.latestFailLow){
            isReset = true;
            break;
         }
      }
   }
   return isReset;
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
  int vSpread  = (int)MarketInfo(Symbol(),MODE_SPREAD);
    if(Bars<100)
     {
      Print("bars less than 100");
      return;
     }
     if(vSpread<=SPREAD  && Period()==Timeframe){ //当前市场的点差小于设置的点差才进行计算
      RefreshRates();
      CalcInd();
      checkProfitByDay(0);
      CheckForClose();
      //当天的 loss 值小于设置的则当天不开单了
      if(!isOpenAutoClose || ind.profitFromIdxDay>=0 || (isOpenAutoClose && ind.profitFromIdxDay<0 && MathAbs(ind.profitFromIdxDay)<MathAbs(LossPerDay))){
         checkForOpen();
      }

         
      Comment("profit:",ind.profitFromIdxDay
      ,"\n lastFailLow:",ind.latestFailLow,
      "\n lastFailHigh:",ind.latestFailHigh,
      "\n emaSignal:",ind.emaSignal,
      "\n ema:",ind.emaArr[0][0],",",ind.emaArr[1][0],",",ind.emaArr[2][0],",",ind.emaArr[3][0],
      "\n prevEMACountOfSell:",ind.prevEMACountOfSell,
      "\n prevEMACountOfBuy:",ind.prevEMACountOfBuy
      );
      }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---

  }
//+------------------------------------------------------------------+
