//+------------------------------------------------------------------+
//|                                                       linear.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//--- input parameters
input int      bbPeriod=20;
input double   bbDeviation=2.0;
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
//| 计算布林带                                                     |
//+------------------------------------------------------------------+
void CalculateBollingerBands(string symbol, int timeframe, int period, double deviation, double &upperBand, double &middleBand, double &lowerBand)
  {
   double ma = iMA(symbol, timeframe, period, 0, MODE_SMA, PRICE_CLOSE, 0);
   double stdDev = iStdDev(symbol, timeframe, period, 0, MODE_SMA, PRICE_CLOSE, 0);

   upperBand = ma + deviation * stdDev;
   lowerBand = ma - deviation * stdDev;
   middleBand = ma;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // 计算布林带指标
   double upperBand, middleBand, lowerBand;
   string single;
   CalculateBollingerBands(_Symbol, PERIOD_M5, bbPeriod, bbDeviation, upperBand, middleBand, lowerBand);

   // 计算线性回归参数
   double slope, intercept;
   CalculateLinearRegression(_Symbol, PERIOD_M5, slope, intercept);

   // 获取当前价格
   double currentPrice = iClose(_Symbol, PERIOD_M5, 0);

   // 计算线性回归值
   //double regressionValue = slope * 0 + intercept;
   Comment("currentPrice:",currentPrice,"\n UpperBand:",upperBand,"\nslop:",slope,"\n intercept",intercept);
   // 如果当前价格低于下轨并且线性回归是正的，执行买入操作
   if (currentPrice < lowerBand && slope > 0)
     {
      // 执行买入逻辑
      //OrderSend(_Symbol, OP_BUY, 0.1, Ask, 3, Ask-200*Point, Ask+1000*Point, "Buy Order", 0, 0, Green);
      single="buy";
     }
   // 如果当前价格高于上轨并且线性回归是负的，执行卖出操作
   else if (currentPrice > upperBand && slope < 0)
     {
      // 执行卖出逻辑
      //OrderSend(_Symbol, OP_SELL, 0.1, Bid, 3, Bid+200*Point, Bid-1000*Point, "Sell Order", 0, 0, Red);
      single="sell";
     }
     Print("sigle:",single,"currentPrice:",currentPrice,"\n UpperBand:",upperBand,"\nslop:",slope,"\n intercept",intercept);
  }
  //+------------------------------------------------------------------+
//| 计算线性回归                                                    |
//+------------------------------------------------------------------+
void CalculateLinearRegression(string symbol, int timeframe, double &slope, double &intercept)
  {
   // 设置回归的数据窗口
   int period = 20;

   // 创建一个数组来存储价格数据
   double prices[];
   ArrayResize(prices, period);

   // 从历史数据获取价格
   for(int i = 0; i < period; i++)
     {
      prices[i] = iClose(symbol, timeframe, i);
     }

   // 计算线性回归参数
   LinearRegression(prices, slope, intercept, period);
  }

//+------------------------------------------------------------------+
//| 计算线性回归 Y=a+bX                                                   |
//+------------------------------------------------------------------+
void LinearRegression(const double &prices[], double &slope, double &intercept, const int &period)
  {
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

   for(int i = 0; i < period; i++)
     {
      sumX += i;
      sumY += prices[i];
      sumXY += i * prices[i];
      sumX2 += i * i;
     }
    // b = (period*sumXY-sumX*sumY)/(period *sumX2-sumX*sumX)
    // a = sumY/period-b*sumX/period

   slope = (period * sumXY - sumX * sumY) / (period * sumX2 - sumX * sumX);
   intercept = (sumY - slope * sumX) / period;
  }
//+------------------------------------------------------------------+
