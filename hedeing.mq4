//+------------------------------------------------------------------+
//|                                                      hedeing.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//--- input parameters
input int      TF=500;
input int      SL=250;
input double   times=1.1;
input double my_lots=0.1;
input int MAXLIMIT = 5;
bool isFirst = true;
const int P1 = 5;
int limit = 0;
int sp = 5;
string comment = "ninazhao";
string prev = "";
double R2R = TF/SL;
double curLots = my_lots;
double buyPrice;
double sellPrice;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
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
void setCurLots(double preLots){
   Print(limit%2);
   if(limit%2==0){
      curLots = NormalizeDouble(preLots * 1.1,3);
   }
   else{
      
      curLots =  NormalizeDouble((R2R+1)/R2R*times*preLots,3);
   }
   
}
void open(int cmd,double price,double sl,double tf){
   int res = OrderSend(Symbol(), cmd, curLots, price, sp,sl, tf,  comment,limit);
   if(res!=-1){
      limit++;
      setCurLots(curLots);
   }

}
void OnTick()
  {
//---
   double MA_5 = iMA(NULL,0,P1,0,MODE_SMA,PRICE_CLOSE,0);
   //开首单的条件，大于5均线的时候才会开多单
   int cmd = OP_BUY;

   if(isFirst){
      //if(Close[0]<MA_5){
         buyPrice  = Ask; 
         sellPrice = Bid;
         open(cmd,buyPrice, buyPrice-(TF+SL)*Point,buyPrice+TF*Point);
         Print("first open"+buyPrice);
         isFirst = false;
         prev = "b";
      //}

   }
   else{
      if(limit<MAXLIMIT){
         //TODO 这里只处理首次下买单
         Print("Bid"+Bid);
         //print("SL"+SL+")
         if(prev=="b"){//上次是买单，本次应该对冲卖单
            if(Bid<=buyPrice-SL*Point){ //如果价格向下穿越就开 sell 单
               open(OP_SELL,Bid, Bid+(TF+SL)*Point, Bid-TF*Point);
               prev = "s";
            }
            
         }
         if(prev=="s"){ //上次是sell单，本次对冲开buy
            if(Ask>=buyPrice){
               open(OP_BUY,Ask,Ask-(TF+SL)*Point,Ask+TF*Point);
               prev = "b";
            }
         }
      }
   }
  }
//+------------------------------------------------------------------+
