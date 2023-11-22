//+------------------------------------------------------------------+
//|                                                      Boll_EA.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//--- input parameters
input double   Lots;
struct Indicator
{
    // 收盘时布林走势
    double bollUpper;
    double bollLower;
    double bollMain;

    // 上一个收盘时布林走势
    double bollUpperPre;
    double bollLowerPre;
    double bollMainPre;

    // 收盘扩张判断
    bool isExpand;
    // 收盘走平或收缩判断
    bool isShrink;
    // 收盘中轨方向
    double trend;

    // 实时的震荡情况
    double stocMain;
    double stocSignal;
    // 是否超买
    bool isOverbuy;
    // 是否超卖
    bool isOversell;
};
#define MAGICMA  20231119
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
void OnTick()
  {
//---
    // 指标计算
    Indicator ind = CalcInd();

    // 检查平仓
    CheckForClose(ind);

    // 检测开仓
    CheckForOpen(ind);
  }

  void CheckForOpen(const Indicator &ind)
{
    // 不要重复下单
    if(OrdersTotal()>0) return;

    // 止盈：布林轨道上下间距
    double TP = MathAbs(ind.bollUpper-ind.bollLower);

    // 止损：布林轨道上下一半间距
    double SL = TP/2;

    //布林走平以及超卖，并且价格接近下轨时：多
    if(ind.isShrink && ind.isOversell && Ask<=(ind.bollLower+TP*0.2))
    {
      //发送仓单（当前货币对，买入方向，开仓量计算，卖价，滑点=0，止损，止赢，订单编号，标上蓝色箭头）
      Print("【多】单开仓结果：",OrderSend(_Symbol,OP_BUY,Lots,Ask,5,Bid-SL,Ask+TP,"EA",MAGICMA,0,Blue));
      return;
    }

    //布林走平以及超买，并且价格接近上轨时：空
    if(ind.isShrink && ind.isOverbuy && Bid>=(ind.bollUpper-TP*0.2))
    {
      //发送仓单（当前货币对，卖出方向，开仓量计算，买价，滑点=0，止损，止赢，订单编号，标上红色箭头）
      Print("【空】单开仓结果：",OrderSend(_Symbol,OP_SELL,Lots,Bid,5,Ask+SL,Bid-TP,"EA",MAGICMA,0,Red));
      return;
    }

}
void CheckForClose(const Indicator &ind)
{
    for(int i=0;i<OrdersTotal();i++)
    {
        //如果 没有本系统所交易的仓单时，跳出循环
        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
        //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
        if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
        // 布林开口向下或到达上轨时平多单
        if(OrderType()==OP_BUY && (ind.isExpand && ind.trend<0 || Bid>=ind.bollUpper))
        {
            Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
            continue;
        }

        // 布林开口向上或到达下轨时平空单
        if(OrderType()==OP_SELL && (ind.isExpand && ind.trend>0 || Ask<=ind.bollLower))
        {
            Print("平仓结果：",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
            continue;
        }
    }
}
Indicator CalcInd()
{
    Indicator ind;
    // 布林走势
    ind.bollUpper = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_UPPER,1);
    ind.bollLower = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_LOWER,1);
    ind.bollMain  = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_MAIN,1);
    ind.bollUpperPre = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_UPPER,2);
    ind.bollLowerPre = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_LOWER,2);
    ind.bollMainPre  = iBands(_Symbol,_Period,21,2,0,PRICE_CLOSE,MODE_MAIN,2);
    // 收盘扩张判断
    ind.isExpand = (ind.bollUpper>ind.bollUpperPre && ind.bollLower<ind.bollLowerPre);
    // 收盘走平或收缩判断
    ind.isShrink = (ind.bollUpper<=ind.bollUpperPre && ind.bollLower>=ind.bollLowerPre);
    // 收盘中轨方向
    ind.trend = ind.bollMain - ind.bollMainPre;

    // 实时的震荡情况
    ind.stocMain = iStochastic(_Symbol,_Period,5,3,3,MODE_SMA,0,MODE_MAIN,0);
    ind.stocSignal = iStochastic(_Symbol,_Period,5,3,3,MODE_SMA,0,MODE_SIGNAL,0);
    // 超买、超卖
    ind.isOverbuy = (ind.stocMain>=70 && ind.stocSignal>=70);
    ind.isOversell = (ind.stocMain<=30 && ind.stocSignal<=30);

    return ind;
}
//+------------------------------------------------------------------+
