//+------------------------------------------------------------------+
//|                                                       KISS.mq4 |
/*
 指标指示器，简易的解读，大小周期结合，蜡烛剩余时间，枢轴支阻线
 */
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, 环球外汇网友交流群@Aother,448036253@qq.com"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define Y_START 40
#define Y_GAP 20

MqlRates dayRates[2];

int timeOfferset = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(1);
   //创建对象
   ObjectCreate(0,"lblTimer",OBJ_LABEL,0,NULL,NULL);
   ObjectCreate(0,"lblTrend",OBJ_LABEL,0,NULL,NULL);
   ObjectCreate(0,"lblMaGroup",OBJ_LABEL,0,NULL,NULL);
   ObjectCreate(0,"lblAuthor",OBJ_LABEL,0,NULL,NULL);
   ObjectCreate(0,"lblAdvice",OBJ_LABEL,0,NULL,NULL);
   //设置内容
   ObjectSetString(0,"lblTimer",OBJPROP_TEXT,_Symbol+"蜡烛剩余");
   ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"MACD判断");
   ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组");
   ObjectSetString(0,"lblAuthor",OBJPROP_TEXT,"作者：环球外汇网@Aother");
   ObjectSetString(0,"lblAdvice",OBJPROP_TEXT,"操作建议：待定");
   //设置颜色
   ObjectSetInteger(0,"lblTimer",OBJPROP_COLOR,clrGreen);
   ObjectSetInteger(0,"lblTrend",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"lblMaGroup",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"lblAuthor",OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,"lblAdvice",OBJPROP_COLOR,clrRed);
   //--- 定位右上角 
   ObjectSetInteger(0,"lblTimer",OBJPROP_CORNER ,CORNER_RIGHT_UPPER); 
   ObjectSetInteger(0,"lblTrend",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,"lblMaGroup",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,"lblAuthor",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   //--- 定位右下角
   ObjectSetInteger(0,"lblAdvice",OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   //设置XY坐标
   ObjectSetInteger(0,"lblTimer",OBJPROP_XDISTANCE,200);   
   ObjectSetInteger(0,"lblTimer",OBJPROP_YDISTANCE,Y_START);
   ObjectSetInteger(0,"lblTrend",OBJPROP_XDISTANCE,200);  
   ObjectSetInteger(0,"lblTrend",OBJPROP_YDISTANCE,Y_START+Y_GAP);
   ObjectSetInteger(0,"lblMaGroup",OBJPROP_XDISTANCE,200);
   ObjectSetInteger(0,"lblMaGroup",OBJPROP_YDISTANCE,Y_START+Y_GAP*2);
   ObjectSetInteger(0,"lblAuthor",OBJPROP_XDISTANCE,200);
   ObjectSetInteger(0,"lblAuthor",OBJPROP_YDISTANCE,Y_START+Y_GAP*3);
   ObjectSetInteger(0,"lblAdvice",OBJPROP_XDISTANCE,450);
   ObjectSetInteger(0,"lblAdvice",OBJPROP_YDISTANCE,20);
    
    // 据观察，黄金，原油等图标画出来的线想右边偏移了一个小时
   if(_Symbol=="XAUUSD"||_Symbol=="XTIUSD")timeOfferset = 60*60;
   // 日线轴心//画线时，时间往前移1小时(60秒*60分)
   CopyRates(_Symbol,PERIOD_D1,0,2,dayRates);
   //昨日开盘与收盘
   ObjectCreate(0,"lnYesterdayOpen",OBJ_TREND,0,dayRates[0].time+timeOfferset,dayRates[0].open,dayRates[1].time+timeOfferset,dayRates[0].open);
   ObjectSetInteger(0,"lnYesterdayOpen",OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,"lnYesterdayOpen",OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,"lnYesterdayOpen",OBJPROP_WIDTH,1);
   ObjectCreate(0,"lnYesterdayClose",OBJ_TREND,0,dayRates[0].time+timeOfferset,dayRates[0].close,dayRates[1].time+timeOfferset,dayRates[0].close);
   ObjectSetInteger(0,"lnYesterdayClose",OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,"lnYesterdayClose",OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,"lnYesterdayClose",OBJPROP_WIDTH,1);
   
   //日线PP
   ObjectCreate(0,"lnDayPP",OBJ_TREND,0,dayRates[1].time+timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
   ObjectSetInteger(0,"lnDayPP",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"lnDayPP",OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,"lnDayPP",OBJPROP_WIDTH,1);
   //日线S1
   ObjectCreate(0,"lnDayS1",OBJ_TREND,0,dayRates[1].time+timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
   ObjectSetInteger(0,"lnDayS1",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"lnDayS1",OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,"lnDayS1",OBJPROP_WIDTH,1);
   //日线R1
   ObjectCreate(0,"lnDayR1",OBJ_TREND,0,dayRates[1].time+timeOfferset,dayRates[0].close,Time[0],dayRates[0].close);
   ObjectSetInteger(0,"lnDayR1",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"lnDayR1",OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,"lnDayR1",OBJPROP_WIDTH,1);
   
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert 运行结束 function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   Print("EA运行结束，已经卸载" );
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 趋势感知：上一个收盘价的指标
   //MACD主要，大周期
   double macdBigMain = iMACD(_Symbol,PERIOD_H4,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
   //MACD信号，大周期
   double macdBigSignal = iMACD(_Symbol,PERIOD_H4,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   //均线组
   double maFst = iMA(_Symbol,PERIOD_H1,37,0,MODE_SMA,PRICE_CLOSE,1);
   double maSlw = iMA(_Symbol,PERIOD_H1,60,0,MODE_SMA,PRICE_CLOSE,1);
   
   //典型： (yesterday_high + yesterday_low + yesterday_close)/3
   //给予收盘价更高权重： (yesterday_high + yesterday_low +2* yesterday_close)/4
   CopyRates(_Symbol,PERIOD_D1,0,2,dayRates);
   double dayHigh =  dayRates[0].high;
   double dayLow =  dayRates[0].low;
   double dayClose = dayRates[0].close;
   // 轴心
   double dayPP = (dayHigh + dayLow + dayClose)/3;
   // 支撑1：(2 * P) - H
   // 阻力1： (2 * P) - L
   double dayS1 = 2*dayPP - dayHigh;
   double dayR1 = 2*dayPP - dayLow;
   
   ObjectMove(0,"lnYesterdayOpen",0,dayRates[0].time+timeOfferset,dayRates[0].open);
   ObjectMove(0,"lnYesterdayOpen",1,Time[0],dayRates[0].open);
   ObjectMove(0,"lnYesterdayClose",0,dayRates[0].time+timeOfferset,dayRates[0].close);
   ObjectMove(0,"lnYesterdayClose",1,Time[0],dayRates[0].close);
   
   ObjectMove(0,"lnDayPP",0,dayRates[1].time+timeOfferset,dayPP);
   ObjectMove(0,"lnDayPP",1,Time[0],dayPP);
   ObjectMove(0,"lnDayS1",0,dayRates[1].time+timeOfferset,dayS1);
   ObjectMove(0,"lnDayS1",1,Time[0],dayS1);
   ObjectMove(0,"lnDayR1",0,dayRates[1].time+timeOfferset,dayR1);
   ObjectMove(0,"lnDayR1",1,Time[0],dayR1);

   // 操作建议
   string advice = "";
   
   //MACD走势判定
   //多头趋势
   if(macdBigSignal>0 && macdBigMain>macdBigSignal)
   {
      ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"4H MACD：多头↑");
      //advice = "守则：只做多，汇价下探触及60均线进多，趋势改变平仓";
   }
   else if(macdBigSignal>0 && macdBigMain<macdBigSignal)
   {
      ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"4H MACD：多头调整");
   }
   else if(macdBigSignal<0 && macdBigMain<macdBigSignal)
   {
      ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"4H MACD：空头↓");
      //advice = "守则：只做空，汇价上探触及60均线进空，趋势改变平仓";
   }
   else if(macdBigSignal<0 && macdBigMain>macdBigSignal)
   {
      ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"4H MACD：空头调整");
      //advice = "守则：只做空，汇价上探触及60均线进空，趋势改变平仓";
   }
   else
   {
      ObjectSetString(0,"lblTrend",OBJPROP_TEXT,"4H MACD：震荡~");
     // advice = "建议：多空皆可，顶部开空，底部开多";   
   }
   
   
   //均线走势判定
   if(maFst>maSlw && Close[1]>maFst && Open[1]>maFst)
   {
      ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组：多头↑");   
   }
   else if(maFst>maSlw && Close[1]<maFst && Open[1]<maFst && (Close[1]>maSlw || Open[1]>maSlw))
   {
      ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组：多头调整");   
   }
   else if(maFst<maSlw && Close[1]<maFst && Open[1]<maFst)
   {
      ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组：空头↓");   
   }
   else if(maFst<maSlw && Close[1]>maFst && Open[1]>maFst && (Close[1]<maSlw || Open[1]<maSlw))
   {
      ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组：空头调整");   
   }
   else
   {
      ObjectSetString(0,"lblMaGroup",OBJPROP_TEXT,"1H均线组：震荡~");   
   }
   
   
   
   // 显示操作建议
   ObjectSetString(0,"lblAdvice",OBJPROP_TEXT,advice);
   ObjectSetInteger(0,"lblAdvice",OBJPROP_XDISTANCE,18*StringLen(advice) + 16); 
   
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 定时刷新计算当前蜡烛剩余时间
   long hour = Time[0] + 60 * Period() - TimeCurrent();
   long minute = (hour - hour % 60) / 60;
   long second = hour % 60;
   ObjectSetString(0,"lblTimer",OBJPROP_TEXT,StringFormat("%s蜡烛剩余：%d分%d秒",_Symbol,minute,second));
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   
}
//+------------------------------------------------------------------+