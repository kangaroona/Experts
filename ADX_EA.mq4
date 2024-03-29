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
input DF Timeframe = M15;
input int SPREAD = 300;
input int ADX_MIN = 20;
input int ADX_MAX = 30;
//input double TP_least=0.3;
input int FastObv = 21;
input int SlowObv = 34;
input int TEMAPeriod = 14;
struct Indicator{
   double ADXCurrent;
   double ADXPrev;
   double ADXPDICur;
   double ADXPDIPrev;
   double ADXMDICur;
   double ADXMDIPrev;
   double SARCur;
   double LowPrev;
   double SARPrev;
   double HighPrev;
   string single;
   double FastEMAofOBV;
   double SlowEMAofOBV;
   double TemaPrev;
   double WeightPre;
   double PrevSL;
   
};
Indicator ind;
long prevBar;
double originTF = 0;
double originSL = 0;
long curBar;
long openBar = 0;
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
bool open(int cmd,double price,double sl,double tf,color arrColor){
   curBar = SeriesInfoInteger(Symbol(),Period,SERIES_LASTBAR_DATE);
   if(getCurOrderCount()==0){ //当前trading池子里没有单子，才会开单
      ind.single = cmd==OP_BUY?"buy":"sell";
      int res = OrderSend(Symbol(), cmd, Lots, price, 5,sl, tf,  "ninazhao_ADX",MAGICMA,0,arrColor);
      if(res<0){
         Print("open fail");
         return false;
      }
      else{
         prevBar = curBar;
         openBar = curBar;
         return true;  
      }
   }
   return false;

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
   curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      prevBar = curBar;
      return true;
   }
   return false;

}
void CheckForClose()
{
   //if(Volume[0]>1) return;
   for(int i=0;i<OrdersTotal();i++)
    {
        //如果 没有本系统所交易的仓单时，跳出循环
        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
        //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
        if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
        int duration = (int)(TimeCurrent()-OrderOpenTime());
        if(OrderType()==OP_BUY)//多单
        {
            
           // Print("duration:",(int)(TimeCurrent()-OrderOpenTime()));
            if(ind.WeightPre<ind.TemaPrev){//如果前一个 bar 的重心在 tema 下面，开始设置 SL
               double curSL = NormalizeDouble(ind.WeightPre-SL*Point,Digits);
               //originTF = Bid+TF*Point;
               double prevSL = ind.PrevSL==0?curSL:ind.PrevSL;
               if(curSL>prevSL){
                  int res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Blue);
                  Print("Modify","openBar:",openBar," SL:",curSL);
                  Print("Modify res",res);
               }
            }
            if(ind.LowPrev>ind.SARPrev && Bid<=ind.SARCur){ //如果趋势向下且当前价格小于 SAR 则平
                Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
                 Comment("SAR Close");
            }
            
            //if(Bid<=originSL || ind.ADXCurrent<ind.ADXPrev){ //到达止损位平仓或 adx 趋势向下，则平多单
            //   Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
            //}
            continue;
        }
        if(OrderType()==OP_SELL)//空单
        {

            if(ind.WeightPre>ind.TemaPrev){
               //originTF = Ask-TF*Point;
               double curSL = NormalizeDouble(ind.WeightPre+SL*Point,Digits);
               double prevSL = ind.PrevSL==0?curSL:ind.PrevSL;
               if(curSL<prevSL){
                  int res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Red);
                  Print("Modify","openBar:",openBar," SL:",curSL);
                  Print("Modify res",res);
               }
            }
            if(ind.HighPrev<ind.SARPrev && Bid>=ind.SARCur){//如果当前的价格大于 SAR 且趋势向上了则平
               Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
               Comment("SAR Close");
            }
            //if(Ask>=originSL || ind.ADXCurrent<ind.ADXPrev){ //到达止损位平仓或大于止盈位且 adx 趋势向下，则平空单
            //   Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
            //}
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
   ind.SARCur = iSAR(NULL,Timeframe,0.02,0.2,0);
   ind.SARPrev = iSAR(NULL,Timeframe,0.02,0.2,1);
   ind.LowPrev = Low[1];
   ind.HighPrev = High[1];
   ind.WeightPre = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
   ind.single = "";
   ind.TemaPrev = iCustom(NULL,Timeframe,"TEMA",TEMAPeriod,0,1);
   ind.FastEMAofOBV = iCustom(NULL,Timeframe,"IndImOfOBV",FastObv,SlowObv,0,0,0);
   ind.SlowEMAofOBV = iCustom(NULL,Timeframe,"IndImOfOBV",FastObv,SlowObv,0,1,0);
   ind.PrevSL = 0;
   
}
void checkForOpen(){
   //if(Volume[0]>1) return;
   if(ind.ADXCurrent>=ADX_MIN && ind.ADXCurrent<=ADX_MAX && ind.ADXPrev<ind.ADXCurrent){//ADX 从下到上横穿ADX 区间时候
      if(ind.ADXPDICur>ind.ADXMDICur && ind.ADXPDICur>ind.ADXPDIPrev && Bid>ind.SARCur && ind.FastEMAofOBV>ind.SlowEMAofOBV){ //+DI>-DI && DI+必须是上升趋势
            if(open(OP_BUY,Ask,0,0,Blue)){//开单成功设置 TF，SL
               originTF = OrderOpenPrice()+TF*Point;
               originSL =  OrderOpenPrice()-SL*Point;
            }

   
      }
      if(ind.ADXPDICur<ind.ADXMDICur && ind.ADXMDICur>ind.ADXMDIPrev && Bid<ind.SARCur && ind.SlowEMAofOBV>ind.FastEMAofOBV){ //DI+<DI- && DI-必须是上升趋势
          if(open(OP_SELL,Bid,0,0,Red)){
             originTF = OrderOpenPrice()-TF*Point;
             originSL = OrderOpenPrice()+SL*Point;
          }
          
      }
   }
}
void OnTick()
  {
//---
//   Print(Period(),"-----",Timeframe);
//   Print(isNewBar());
  // Print("xxxxxxx",Bars);
   int vSpread  = (int)MarketInfo(Symbol(),MODE_SPREAD);
    if(Bars<100)
     {
      Print("bars less than 100");
      return;
     }
   if(vSpread<=SPREAD){ //当前市场的点差小于设置的点差才进行计算
      CalcInd();
      checkForOpen();
      CheckForClose();
      Comment(
      "Volume:",Volume[0],
      "\n SAR:",ind.SARCur,
      "\n TEMAPrev:",ind.TemaPrev,
      "\n WeightPre",ind.WeightPre,
      "\n fastobv:",ind.FastEMAofOBV,
      "\n slowobv:",ind.SlowEMAofOBV);
     }
     //Print("Periond=",Period(),"=======","spread",vSpread);
   
  }
//+------------------------------------------------------------------+
