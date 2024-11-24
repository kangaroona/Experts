#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
extern double my_lots= 0.01;        //Lots
extern int    zhi_s  =50;      //StopLoss
extern string magic  ="ninazhao0327@gmail.com";

int    dian_c=6,
       wei_s =100;
double dian_z=0.1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
    if(Point < 0.001)
    {
        dian_z=0.0001;
        wei_s=100000;
    }
     else if(Point == 0.001)
     {
         dian_z=0.01;
         wei_s=1000;
     }
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
void OnTick()
  {
//---
      static datetime  time=0;
      static double    zhi_y=100;      //takepofit
      int       ab=0;
      bool      bo=false;
      double    close_1=Close[1],
                 close_2=Close[2],
                 open_1=Open[1],
                 open_2=Open[2];


      double MA_5 =iMA(NULL, PERIOD_CURRENT,5,0,MODE_SMMA,PRICE_CLOSE,0);

      dian_c=StrToInteger(DoubleToStr((Ask-Bid)*wei_s, 0));
      //Print("total order:"+OrdersTotal());
//      for(int i=OrdersTotal()-1; i>=0; i--)
//      {
//          bo= OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
//          if(bo==false)break;
//          Print("ordersymbol:"+OrderSymbol()+",Symbol:"+Symbol());
//          if(OrderSymbol()!=Symbol())continue;
//          if(OrderType() == OP_BUY && Bid >= zhi_y)
//          {
//              bo=OrderClose(OrderTicket(), OrderLots(), Bid, 5);
//              //if(bo==true)
//              //{
//              //    for(int L=OrdersTotal()-1; L>=0; L--)
//              //    {
//              //        bo=OrderSelect(L, SELECT_BY_POS, MODE_HISTORY);
//              //        if(bo==false)break;
//              //        if(OrderSymbol()!=Symbol())continue;
//              //        if(OrderType() == OP_BUY)
//              //        {
//              //            OrderClose(OrderTicket(), OrderLots(), Bid, 5);
//              //            zhi_y=0;
//              //        }
//              //        RefreshRates();
//              //    }
//              //}
//          }
//          else if(OrderType() == OP_SELL && Ask <= zhi_y)
//          {
//              bo=OrderClose(OrderTicket(), OrderLots(), Ask, 5);
//              if(bo==true)
//              {
//                  for(int LI=OrdersTotal()-1; LI>=0; LI--)
//                  {
//                      bo=OrderSelect(LI, SELECT_BY_POS, MODE_HISTORY);
//                      if(bo==false)break;
//                      if(OrderSymbol()!=Symbol())continue;
//                      if(OrderType() == OP_SELL)
//                      {
//                          OrderClose(OrderTicket(), OrderLots(), Ask, 5);
//                          zhi_y=0;
//                      }
//                      RefreshRates();
//                  }
//              }
//
//          }
//      }
      if(close_2 > MA_5 && close_1 > MA_5 && open_2 - close_2 >0 && open_1 - close_1 > 0 && time != Time[0])
      {
          if(!Check(Symbol(), my_lots, OP_SELL)) return;
          if(my_lots<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
          {
              Comment("交易量过小无法交易");
              return;
          }
          OrderSend(Symbol(), OP_BUY, my_lots, Ask, dian_c, Ask-zhi_s*Point, Ask+zhi_y*Point, magic, 00000000);

              time=Time[0];
              //zhi_y=Low[1];

      }
      else if(close_2 < MA_5 && close_1 < MA_5 && close_2 - open_2 >0 && close_1 - open_1 > 0 && time != Time[0])
      {
         if(!Check(Symbol(), my_lots, OP_SELL)) return;
         if(my_lots<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
          {
              Comment("交易量过小无法交易");
              return;
          }
          OrderSend(Symbol(), OP_SELL, my_lots, Bid, dian_c,Bid+zhi_s*Point, Bid-zhi_y*Point, magic, 0000000);
          

              time=Time[0];
              //zhi_y=High[1];

      }
  }
//+------------------------------------------------------------------+
bool Check(string symb, double lots,int type)
  {
   double free_margin=AccountFreeMarginCheck(symb,type, lots);
   //-- 如果资金不够
   if(free_margin<0)
     {
      string oper=(type==OP_BUY)?"买入":"卖出";
      Print("资金不足以进行", oper," ",lots, " ", symb, " 错误编号",GetLastError());
      return(false);
     }
   //--- 检验成功
   return(true);
  }
