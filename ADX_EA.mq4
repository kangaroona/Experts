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
   int res = OrderSend(Symbol(), cmd, Lots, price, 5,sl, tf,  "ninazhao_ADX",0000);

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
void OnTick()
  {
//---
   string single = "";
   double ADXCurrent = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MAIN,0);
   double ADXPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MAIN,1);
   double ADXPDICur = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,0);
   double ADXPDIPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,1);
   double ADXPDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,2);
   double ADXMDICur = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,0);
   double ADXMDIPrev = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,1);
   double ADXMDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,2);
   if(ADXCurrent>25 && ADXCurrent>ADXPrev){
      if(ADXPDICur>ADXMDICur && ADXPDIPrev==ADXMDIPrev && ADXPDIPrev2<ADXMDIPrev2){
        
         if(getCurOrderCount()==0){ //trading 池子里没有单子才会下单
            single = "buy";
            double ATRCur = iATR(NULL,0,Period,0);
            double SLCur = SL; 
            if(!isSL){
               SLCur = ATRCur*100*Point*1.1;
            }
            Print("SLCur = "+SLCur);
            open(OP_BUY,Ask,Ask-SLCur,Ask+1000*Point);
         }

      }
      if(ADXPDICur<ADXMDICur && ADXPDIPrev==ADXMDIPrev && ADXPDIPrev2>ADXMDIPrev2){
         if(getCurOrderCount()==0){ //trading 池子里没有单子才会下单
            single = "sell";
            open(OP_SELL,Bid,Bid+200*Point,Bid-2000*Point);
         }
      }
   }
   
   Comment("ADX single: ",single,"\n ADX value:",ADXCurrent,"\n DI+: ",ADXPDICur,"\n DI-: ",ADXMDICur);
   
  }
//+------------------------------------------------------------------+
