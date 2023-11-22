//+------------------------------------------------------------------+
//|                                                       ADX_EA.mq4 |
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
input int      Period=14;
input double   Lots = 0.1;
input int      TF = 1000;
input bool     isSL = false;
input int      SL=200; //设置了 isSL 这个值生效
input int      ADX_period=25;
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
input DF Timeframe = H1;
input int sp = 300;
input int ADX_MIN = 20;
input int ADX_MAX = 25;
long prevBar;
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void open(int cmd,double price,double sl,double tf){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      int res = OrderSend(Symbol(), cmd, Lots, price, 5,sl, tf,  "ninazhao_ADX",0000);
      if(res<0){
         Print("open fail");
      }
      else{
         prevBar = curBar;
      }
   }

}
int getCurOrderCount(){
   int orderCount = 0;
   bool bo = false;
   for(int i=OrdersTotal()-1;i>=0;i--){
      bo= OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(!bo) continue;
      if(OrderSymbol()==Symbol() && OrderComment()=="ninazhao_ADX"){
         orderCount++;
         break;
      }
  
   }
   return orderCount;
}
bool isNewBar(){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      prevBar = curBar;
      return true;
   }
   return false;

}
void OnTick()
  {
//---
//   Print(Period(),"-----",Timeframe);
//   Print(isNewBar());
   if(Period()==Timeframe){
      string single = "";
      double ADXCurrent = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MAIN,0);
      double ADXPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MAIN,1);
      double ADXPDICur = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double ADXPDIPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,1);
      double ADXPDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,2);
      double ADXMDICur = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,0);
      double ADXMDIPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,1);
      double ADXMDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,2);
      if(ADXCurrent>=ADX_period && ADXPrev<ADXCurrent){//ADX 从下到上横穿ADX_period
         if(ADXPDICur>ADXMDICur && ADXPDICur>ADXPDIPrev){ //+DI>-DI && DI+必须是上升趋势
           
            if(getCurOrderCount()==0){ //trading 池子里没有单子才会下单
               single = "buy";
               double ATRCur = iATR(NULL,0,Period,0);
               double SLCur = SL*Point; 
               if(!isSL){
                  SLCur = ATRCur*100*Point*1.1;
               }
               Print("SLCur = "+SLCur);
               open(OP_BUY,Ask,Ask-SLCur,Ask+TF*Point);
            }
   
         }
         if(ADXPDICur<ADXMDICur && ADXMDICur>ADXMDIPrev){ //DI+<DI- && DI-必须是上升趋势
            if(getCurOrderCount()==0){ //trading 池子里没有单子才会下单
               single = "sell";
               open(OP_SELL,Bid,Bid+SL*Point,Bid-TF*Point);
            }
         }
      }
      
      Comment("ADX single: ",single,"\n ADX value:",ADXCurrent,"\n DI+: ",ADXPDICur,"\n DI-: ",ADXMDICur);
     }
   
  }
//+------------------------------------------------------------------+
