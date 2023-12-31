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
input int      SL=200; 
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
input int SPREAD = 300;
input int ADX_MIN = 20;
input int ADX_MAX = 25;
input double TP_least=0.3;
struct Indicator{
   double ADXCurrent;
   double ADXPrev;
   double ADXPDICur;
   double ADXPDIPrev;
   double ADXMDICur;
   double ADXMDIPrev;
   string single;
};
Indicator ind;
long prevBar;
#define MAGICMA  20231122
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
void open(int cmd,double price,double sl,double tf,color arrColor){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar && getCurOrderCount()==0){ //如果当前 bar 没有开会单且当前trading池子里没有单子，才会开单
      ind.single = cmd==OP_BUY?"buy":"sell";
      int res = OrderSend(Symbol(), cmd, Lots, price, 5,sl, tf,  "ninazhao_ADX",MAGICMA,0,arrColor);
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
void CheckForClose()
{
   for(int i=0;i<OrdersTotal();i++)
    {
        //如果 没有本系统所交易的仓单时，跳出循环
        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
        //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
        if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;

        if(OrderType()==OP_BUY)//多单
        {
            double originTF = OrderOpenPrice()+TF*Point;
            double originSL =  OrderOpenPrice()-SL*Point;
            if(Bid>=originTF){//价格冲破止盈，则重新设置止损
               double curSL = NormalizeDouble(TF*Point*TP_least+OrderOpenPrice(),Digits);
               int res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Blue);
               if(!res){
                  Print("modify fail");
               }
            }
            if(Bid<=originSL || ind.ADXCurrent<ind.ADXPrev){ //到达止损位平仓或 adx 趋势向下，则平多单
               Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
            }
            continue;
        }
        if(OrderType()==OP_SELL)//空单
        {
            double originTF = OrderOpenPrice()-TF*Point;
            double originSL = OrderOpenPrice()+SL*Point;
            if(Ask<=originTF){
               double curSL = NormalizeDouble(OrderOpenPrice()-TF*Point*TP_least,Digits);
               int res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Red);
               if(!res){
                  Print("modify fail");
               }
            }
            if(Ask>=originSL || ind.ADXCurrent<ind.ADXPrev){ //到达止损位平仓或大于止盈位且 adx 趋势向下，则平空单
               Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
            }
            continue;
        }
    }   
}
//获取指标
void CalcInd(){
   ind.ADXCurrent = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_MAIN,0);
   ind.ADXPrev = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_MAIN,1);
   ind.ADXPDICur = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_PLUSDI,0);
   ind.ADXPDIPrev = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_PLUSDI,1);
   //double ADXPDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_PLUSDI,2);
   ind.ADXMDICur = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_MINUSDI,0);
   ind.ADXMDIPrev = iADX(NULL,Timeframe,Period,PRICE_WEIGHTED,MODE_MINUSDI,1);
   ind.single = "";
   //double ADXMDIPrev2 = iADX(NULL,0,Period,PRICE_WEIGHTED,MODE_MINUSDI,2);
}
void checkForOpen(){
   if(ind.ADXCurrent>=ADX_MIN && ind.ADXCurrent<=ADX_MAX && ind.ADXPrev<ind.ADXCurrent){//ADX 从下到上横穿ADX 区间时候
      if(ind.ADXPDICur>ind.ADXMDICur && ind.ADXPDICur>ind.ADXPDIPrev){ //+DI>-DI && DI+必须是上升趋势
            open(OP_BUY,Ask,0,0,Blue);
   
      }
      if(ind.ADXPDICur<ind.ADXMDICur && ind.ADXMDICur>ind.ADXMDIPrev){ //DI+<DI- && DI-必须是上升趋势
          open(OP_SELL,Bid,0,0,Red);
      }
   }
}
void OnTick()
  {
//---
//   Print(Period(),"-----",Timeframe);
//   Print(isNewBar());
   int vSpread  = (int)MarketInfo(Symbol(),MODE_SPREAD);
   if(vSpread<=SPREAD){ //当前市场的点差小于设置的点差才进行计算
      CalcInd();
      checkForOpen();
      CheckForClose();
      Comment("ADX single: ",ind.single,"\n ADX value:",ind.ADXCurrent,"\n DI+: ",ind.ADXPDICur,"\n DI-: ",ind.ADXMDICur);
     }
     //Print("Periond=",Period(),"=======","spread",vSpread);
   
  }
//+------------------------------------------------------------------+
