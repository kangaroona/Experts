//+------------------------------------------------------------------+
//|                                                   hedeing_v7.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
input int      TF=9000;
input int      SL=3000;
input int SPREAD = 100;
enum DF
  {
   current=PERIOD_CURRENT,
   M1=PERIOD_M1,
   M5=PERIOD_M5,
   M15=PERIOD_M15,
   M30=PERIOD_M30,
   H1=PERIOD_H1,
   H4=PERIOD_H4,
   D1=PERIOD_D1
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input DF Timeframe = M5; //Timeframe
input double   times=1.3;
input DF Heikin_TimeFrame = H4;
input double Lots=0.2;
input int MAXLIMIT = 7; //Hedeing limit
input int SafeLimit = 10; //Safe limit
input int firstOrderTP = 5000;// following mode: entry point
input int firstOrderSL = 2000;// following mode: pullback
input int TPCount = 5; //following mode: entry times
input double percentOfAddLots = 0.5; //following mode: entry %
input double targetProfit = 1;
input double CheckHours = 2; //DiffHours for check Hedeing profit
input int Diff_pips = 40;//diff pips from EMA5 to EMA6
input DF EMA50TimeFrame = M5;
input int firstOrderCalBar = 5; //the first order calculate bar
input int firstOrderMinBars = 3;
input int maxCloseBarFromStart = 5; //max bar number check close
input int forBidden_pips = 20;

extern string TIME="----------------Time----------------------";
input string TradingStartTime = "03:15";  // trading start time
input string TradingEndTime = "22:00"; //trading end time
input string CloseCheckTime = "21:30"; //start checking close time
input string BollingStartTime = "04:00"; //bolling start time
input string BollingEndTime = "21:00"; //bolling end time

extern string MACD="----------------MACD----------------------";
input DF MACD_TimeFrame = M15;
input int Fast = 12;
input int Slow = 26;
input int Signal = 9;
input double MACD_From= -0.15;
input double MACD_To = 0.15;
input ENUM_APPLIED_PRICE MACDPrice = PRICE_CLOSE;

extern string ATR="----------------ATR----------------------";
input DF ATR_TimeFrame = M15;
input int ATR_Period = 3;
input double ATR_Level = 25;
input double ATR_Cap=40;
input int ATR_MA_Period = 13;
input  ENUM_MA_METHOD ATR_MA_Method = MODE_EMA;

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
input double PSARMax = 0.2;                      // PSAR Max
extern string BBand="----------------BBand----------------------";
input DF Bbands_TimeFrame;
input int Bbands_Period = 9;
input double Bbands_Deviation=1;
input double BbTimes = 2;
input double CloseRangePips = 500;
input double OpenRangePips = 200;
extern string Loss="----------------Loss----------------------";
input bool isOpenAutoClose = true;
input double LossPerDay = 100;

extern string Useless="----------------Useless----------------------";
input int ConsecutiveBars = 3;
input int maxBarCount = 3;
input int minBarCount = 1;

enum TradingType
  {
   NORMAL=0, // 初始化
   HEDGING=1, //hedeing
   ADDLOTS=2, //顺势加仓
   SAFELOTS=3, //防守加仓
   SCALPING=4, //削头皮
  };
struct Indicator
  {
   double            emaArr[4][3];
   double            Ema5_0;
   double            Ema6_0;
   double            Ema5_1;
   double            Ema6_1;
   double            Ema5_2;
   double            Ema6_2;
   bool              isNewBar;
   int               emaSignal;
   double            Bbands1_up;
   double            Bbands1_down;
   double            Bbands1_middle;
   double            Ema7_low;
   double            Ema7_high;
   double            barAverage;
   double            Weight1;
   double            Weight2;
   double            profitFromIdxDay;
   int               prevEMACountOfSell;
   int               prevEMACountOfBuy;
   int               OpenBarShift;
   int               orderCount;
   double            high;
   double            low;
   string            firstFlag;
   double            firstOpenPrice;
   string            prevFlag;
   double            prevLots;
   bool              isHashedeing;
   TradingType       tradingType;
   double            prevOpenPrice;
   double            firstSL;
   double            firstOrderLoss;
   string            HeiKinShadow;
   string            HeiKinBody;
   string            HeiKinShadow_EMA;
   string            HeiKinBody_EMA;
   double            MACD_main;
   double            MACD_signal;
   double            firstSafeLots;
   double            heideingSum;
   datetime          firstOpenTime;
   int               tradingCount;
   double            ATRNum;
   double            ATRNumPrev;
   double            MA4ATR;
   double            hedging_SL;
   double            hedging_TP;
   double            isLastSafeOrder;
   double            typical;
   int               countOfBarsGreaterThanOpen;
   double            forBiddenLow;
   double            forBiddenHigh;
  };
Indicator ind;
int emaperiod[];
int closeOrder[];
double safeLots[];
long prevBar=0;
bool isFirst = true;
double curLots = Lots;
double R2R = TF/SL;
string TPLineName = "TPLINE";
string FirstSLLINE = "firstSLLINE";
int startSnds = 0;
int endSnds = 0;
int preCloseSnds = 0;
int bollingStartSnds = 0;
int bollingEndSnds = 0;
double atrArray[];
double maArray[];
int initATRBars;
long prevATRBar;
string slCacheKey = "hedging_SL_"+Symbol();
#define COMMENT  "HedeingTP_20240929_"+IntegerToString(Timeframe)
#define MAGICMA  20240903
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   string res[],resEnd[],resClose[],resBollingArr[],resBollingEndArr[];
   string sep=":";                // A separator as a character
   ushort u_sep;
   u_sep=StringGetCharacter(sep,0);

   int curTime  = getCurTimeSnds();
   int startLen=StringSplit(TradingStartTime,u_sep,res);
   int endLen = StringSplit(TradingEndTime,u_sep,resEnd);
   int closeLen = StringSplit(CloseCheckTime,u_sep,resClose);
   int bollingStartLen = StringSplit(BollingStartTime,u_sep,resBollingArr);
   int bollingEndLen = StringSplit(BollingEndTime,u_sep,resBollingEndArr);
   ind.firstSafeLots = getFirstSafeLotsByInit(Lots,MAXLIMIT+1);
   if(startLen==2)
     {
      startSnds = (int)(StringToInteger(res[0])*60*60+StringToInteger(res[1])*60);
     }
   if(endLen==2)
     {
      endSnds = (int)(StringToInteger(resEnd[0])*60*60+StringToInteger(resEnd[1])*60);
     }
   if(closeLen==2)
     {
      preCloseSnds = (int)(StringToInteger(resClose[0])*60*60+StringToInteger(resClose[1])*60);
     }
   if(bollingStartLen==2)
     {
      bollingStartSnds = (int)(StringToInteger(resBollingArr[0])*60*60+StringToInteger(resBollingArr[1])*60);
     }
   if(bollingEndLen==2)
     {
      bollingEndSnds = (int)(StringToInteger(resBollingEndArr[0])*60*60+StringToInteger(resBollingEndArr[1])*60);
     }
   Print("curTime:",curTime," start:",startSnds,",endSnds:",endSnds,",preCloseSnds:",preCloseSnds);


   EventSetTimer(60);
   ind.isNewBar = true;
   for(int i =0; i<4; i++)
     {
      for(int j=0; j<3; j++)
        {
         ind.emaArr[i][j] = 0;
        }
     }
   ArrayResize(emaperiod,4);
   ArrayResize(safeLots,SafeLimit);
   setSafeLotsByinitLots(ind.firstSafeLots,R2R);
   emaperiod[0] = EMA1;
   emaperiod[1] = EMA2;
   emaperiod[2] = EMA3;
   emaperiod[3] = EMA4;
   ind.prevEMACountOfSell = 0;
   ind.prevEMACountOfSell = 0;
   ind.orderCount = 0;
   ind.firstFlag = "";
   ind.firstOpenPrice = 0;
   ind.isHashedeing = false;
   ind.firstSL = 0;
   ind.tradingType = NORMAL;
   ind.countOfBarsGreaterThanOpen = 0;
   ind.forBiddenLow = 0;
   ind.forBiddenHigh = 0;
   ArraySetAsSeries(atrArray, true);
   ArrayResize(atrArray, Bars);
// 计算初始的 ATR 值
   for(int i = 0; i < Bars - ATR_Period; i++)
     {
      atrArray[i] = iATR(NULL, ATR_TimeFrame, ATR_Period, i);
     }
   initATRBars = iBars(NULL,ATR_TimeFrame);

//ind.shoudOpen = true;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   ObjectsDeleteAll(0,0,OBJ_HLINE);
   EventKillTimer();
   ObjectsDeleteAll(0, 0, OBJ_LABEL);

   Print("EA运行结束，已经卸载");

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getFirstSafeLotsByInit(double initLots,int count)
  {
//通过初始化的lots，算出 safeOrder 的首单 lots
   double lotsArr[];
   ArrayResize(lotsArr,count);
   lotsArr[0] = initLots;
   double sum = 0;
   for(int i=1; i<count; i++)
     {
      if(i%2==0)
        {
         lotsArr[i] = RoundToTwoDecimalPlaces(lotsArr[i-1] * times);
        }
      else
        {
         lotsArr[i] =  RoundToTwoDecimalPlaces((R2R+1)/R2R*times*lotsArr[i-1]);
        }
      if(i%2!=0)
        {
         sum+=lotsArr[i];
        }
     }
   ind.heideingSum = RoundToTwoDecimalPlaces(sum);
   return RoundToTwoDecimalPlaces(sum/R2R);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setSafeLotsByinitLots(double initLots,double percent)
  {
   safeLots[0]=initLots;
   for(int i = 1; i < SafeLimit; i++)
     {
      double curSum = ind.heideingSum;
      for(int j=0; j<i; j++)
        {
         curSum+=safeLots[j];
        }
      safeLots[i] = RoundToTwoDecimalPlaces(curSum/percent);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getCurTimeSnds()
  {
   int h=TimeHour(TimeCurrent());
   int m = TimeMinute(TimeCurrent());
   int curTimeSnds = h*60*60+m*60;
   return curTimeSnds;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isTradingPeriod()
  {
   int curTimeSnds = getCurTimeSnds();
   if(curTimeSnds>startSnds && curTimeSnds<endSnds)
      return true;
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool shouldBollingTrading(int period)
  {
   int curTimeSnds = getCurTimeSnds();
   if(curTimeSnds> bollingStartSnds && curTimeSnds<bollingEndSnds && isBollingMidWithinRangeByPeriod(period))
      return true;
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isBollingMidWithinRangeByPeriod(int period)
  {

   for(int i=1; i<=period; i++)
     {
      double curBollingMid = NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,i),Digits);
      if(curBollingMid<Low[i] || curBollingMid>High[i])
         return false;
     }
   return true;


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar(int timeFrame=0)
  {
   long curBar = SeriesInfoInteger(Symbol(),timeFrame,SERIES_LASTBAR_DATE);
   if(curBar!=prevBar)
     {
      prevBar = curBar;
      return true;
     }
   return false;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool open(int cmd,double price,double sl,double tf,color arrColor)
  {
//ind.single = cmd==OP_BUY?"buy":"sell";
   Print("open lots:",curLots,",orderCount:",ind.orderCount,",firstFlag:",ind.firstFlag,",prevLots:",ind.prevLots,",tradingtype:",ind.tradingType,",prevFlag:",ind.prevFlag,",preOpenPrice:",ind.prevOpenPrice,",tf:",tf,",price:",price,",spread:",SPREAD*Point,",ATR:",ind.ATRNum,",MA4ATR:",ind.MA4ATR);
   if(curLots<=0)
      return false;
   int res = OrderSend(Symbol(), cmd, curLots, price, 5,sl, tf,  COMMENT,MAGICMA,0,arrColor);
   if(res<0)
     {
      Print("open fail:",GetLastError());
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalcInd()
  {
   ind.isNewBar = isNewBar();
   ind.MACD_main = NormalizeDouble(iMACD(NULL,MACD_TimeFrame,Fast,Slow,Signal,MACDPrice,MODE_MAIN,0),Digits);
   ind.MACD_signal = NormalizeDouble(iMACD(NULL,MACD_TimeFrame,Fast,Slow,Signal,MACDPrice,MODE_SIGNAL,0),Digits);
   long curBar = SeriesInfoInteger(Symbol(),(int)ATR_TimeFrame,SERIES_LASTBAR_DATE);
   ind.ATRNum = NormalizeDouble(iATR(NULL,ATR_TimeFrame,ATR_Period,0),Digits);
   ind.ATRNumPrev = NormalizeDouble(iATR(NULL,ATR_TimeFrame,ATR_Period,1),Digits);
   if(prevATRBar!=curBar)
     {
      if(iBars(NULL,ATR_TimeFrame)!=initATRBars)
        {
         int size = ArraySize(atrArray);
         ArrayResize(atrArray,ArraySize(atrArray)+1);
         // 移动数组中的旧值
         for(int i = size; i > 0; i--)
           {
            atrArray[i] = atrArray[i - 1];
           }
         // 插入最新的 ATR 值到数组的开头
         atrArray[0] = ind.ATRNum;

        }
      prevATRBar = curBar;
     }
   else
     {
      atrArray[0] = ind.ATRNum;
     }
   if(ind.isNewBar)
     {
      int curEmaSignal = 0;
      ind.emaSignal = 0;
      //Print("emaperiod=",ArraySize(emaperiod));
      for(int i=0; i<ArraySize(emaperiod); i++)
        {
         for(int j=0; j<3; j++)
           {
            ind.emaArr[i][j] = NormalizeDouble(iMA(NULL,Timeframe,emaperiod[i],0,EMAMethod,EMAPrice,j+1),Digits);
           }
        }
      int zeroCount = 0;
      for(int k=0; k<ArraySize(emaperiod); k++)
        {
         double EMA1OfPeriod = ind.emaArr[k][0];
         double EMA2OfPeriod = ind.emaArr[k][1];
         if(EMA1OfPeriod>EMA2OfPeriod)
           {
            curEmaSignal++;
           }
         if(EMA1OfPeriod<EMA2OfPeriod)
           {
            curEmaSignal--;
           }
         if(EMA1OfPeriod == EMA2OfPeriod)
           {
            zeroCount++;
           }
        }
      if(zeroCount<2)
        {
         if(curEmaSignal>=2)
            ind.emaSignal = 1;
         if(curEmaSignal<=-2)
            ind.emaSignal = -1;
        }
      ind.Ema5_0 = NormalizeDouble(iMA(NULL,EMA50TimeFrame,EMA5,0,EMAMethod,EMAPrice,0),Digits);
      ind.Ema6_0 = NormalizeDouble(iMA(NULL,EMA50TimeFrame,EMA6,0,EMAMethod,EMAPrice,0),Digits);
      ind.Ema5_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema6_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema5_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,2),Digits);
      ind.Ema6_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,2),Digits);

      ind.Ema7_high = NormalizeDouble(iMA(NULL,Bbands_TimeFrame,Bbands_Period,0,EMAMethod,PRICE_HIGH,0),Digits);
      ind.Ema7_low = NormalizeDouble(iMA(NULL,Bbands_TimeFrame,Bbands_Period,0,EMAMethod,PRICE_LOW,0),Digits);

      ind.Bbands1_middle = NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,0),Digits);
      ind.Bbands1_up = NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_UPPER,0),Digits);
      ind.Bbands1_down = NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_LOWER,0),Digits);
      ind.typical = NormalizeDouble((Low[0]+High[0]+Open[0])/3,Digits);
      ind.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
      ind.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
      double HeiKinLow_High = NormalizeDouble(iCustom(NULL,Heikin_TimeFrame,"Heiken Ashi",0,0),Digits); //red
      double HeiKinHigh_Low = NormalizeDouble(iCustom(NULL,Heikin_TimeFrame,"Heiken Ashi",1,0),Digits); //white
      double HeiKinOpen = NormalizeDouble(iCustom(NULL,Heikin_TimeFrame,"Heiken Ashi",2,0),Digits);   //red
      double HeiKinClose = NormalizeDouble(iCustom(NULL,Heikin_TimeFrame,"Heiken Ashi",3,0),Digits);  //white
      //Print("low/high=",HeiKinLow_High,",high/low=",HeiKinHigh_Low,",open=",HeiKinOpen,",close=",HeiKinClose);
      ind.HeiKinShadow = HeiKinLow_High>HeiKinHigh_Low?"sell":"buy";
      ind.HeiKinBody = HeiKinOpen>HeiKinClose?"sell":"buy";

      double HeiKinLow_High_EMA = NormalizeDouble(iCustom(NULL,Timeframe,"Heiken Ashi",0,0),Digits); //red
      double HeiKinHigh_Low_EMA = NormalizeDouble(iCustom(NULL,Timeframe,"Heiken Ashi",1,0),Digits); //white
      double HeiKinOpen_EMA = NormalizeDouble(iCustom(NULL,Timeframe,"Heiken Ashi",2,0),Digits);   //red
      double HeiKinClose_EMA = NormalizeDouble(iCustom(NULL,Timeframe,"Heiken Ashi",3,0),Digits);  //white
      ind.HeiKinShadow_EMA = HeiKinLow_High_EMA>HeiKinHigh_Low_EMA?"sell":"buy";
      ind.HeiKinBody_EMA = HeiKinOpen_EMA>HeiKinOpen_EMA?"sell":"buy";

      setCountOfEMA();

     }
   else
     {
      atrArray[0] = NormalizeDouble(iATR(NULL,ATR_TimeFrame,ATR_Period,0),Digits);
     }
   double calculatedBars = iMAOnArray(atrArray, 0, ATR_MA_Period, 0, ATR_MA_Method, 0);
   ind.MA4ATR = NormalizeDouble(calculatedBars,Digits);
   if(ind.orderCount==1 && ind.tradingType==NORMAL)  //afer first order, caculate dynamic SL
     {
      if(ind.ATRNum>=ATR_Cap)
         ind.hedging_SL = MathMax(SL*Point,ATR_Cap);
      else
         ind.hedging_SL = MathMax(SL*Point,ind.ATRNum); //TODO
      ind.hedging_TP = R2R * ind.hedging_SL;
      GlobalVariableSet(slCacheKey,ind.hedging_SL);
     }
   else
      if(GlobalVariableGet(slCacheKey))
        {
         ind.hedging_SL = GlobalVariableGet(slCacheKey);
         ind.hedging_TP = R2R * ind.hedging_SL;
        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setNormalFirstOrderLots()
  {
   curLots = Lots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setCountOfEMA()  //
  {
   int prevBuyCount = 0;
   int prevSellCount = 0;
   string flagArr[2] = {"buy","sell"};
   for(int j=0; j<2; j++)
     {
      for(int i=1; i<5; i++)
        {
         double fast =  NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,i),Digits);
         double slow =  NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,i),Digits);
         double curWeightValue = NormalizeDouble((Open[i]+Close[i]+Low[i]+High[i])/4,2);
         double curBbandUp =  NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_UPPER,i),Digits);
         double curBbandDown = NormalizeDouble(iBands(NULL,Bbands_TimeFrame,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_LOWER,i),Digits);
         if(flagArr[j]=="buy")
           {
            if(curWeightValue>=curBbandUp)
              {
               prevBuyCount++;
              }
            else
               break;
           }
         if(flagArr[j]=="sell")
           {
            if(curWeightValue<=curBbandDown)
              {
               prevSellCount++;
              }
            else
               break;
           }

        }
     }
   ind.prevEMACountOfSell = prevSellCount;
   ind.prevEMACountOfBuy = prevBuyCount;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isLatestCloseBar()   //当前 bar 是否是最新的 closebar
  {
   int latestCloseBarIdx = -1;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         //如果仓单货币对不是当前货币对时，继续选择
         if(OrderSymbol()!=_Symbol)
            continue;
         int curBarIdx = iBarShift(NULL,Timeframe,OrderCloseTime());
         if(curBarIdx==0)
            latestCloseBarIdx=0;
         break;
        }

     }
   if(latestCloseBarIdx == 0)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setForbiddenZone()
  {
   if(ind.orderCount==0)
     {
      for(int i=OrdersHistoryTotal()-1; i>=0; i--)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
           {
            //如果仓单货币对不是当前货币对时，继续选择
            if(OrderSymbol()!=_Symbol)
               continue;
            double diffPips = NormalizeDouble(MathAbs(OrderClosePrice()-OrderOpenPrice()),Digits);
            double result = OrderProfit() + OrderCommission() + OrderSwap();
            int openBar = iBarShift(NULL, Timeframe, OrderOpenTime(), false);
            int closeBar = iBarShift(NULL, Timeframe, OrderCloseTime(), false);
            // 计算索引差值
            int barDiff = openBar - closeBar;
            if(result<0 && diffPips>SL*Point*0.5 && OrderLots()==Lots && barDiff<maxCloseBarFromStart)
              {
               
               ind.forBiddenLow = MathMin(OrderClosePrice(),OrderOpenPrice())-forBidden_pips*Point;
               ind.forBiddenHigh = MathMax(OrderClosePrice(),OrderOpenPrice())+forBidden_pips*Point;
               createLine("forbiddenLow",ind.forBiddenLow,clrSalmon);
               createLine("forbiddenHigh",ind.forBiddenHigh,clrWhiteSmoke);
               Print("set forbidden zone: low=",ind.forBiddenLow,",high=",ind.forBiddenHigh,",diffPips=",diffPips);
               
              }
              break;
           }

        }
     
     }
   else
     {
      clearForBiddenZone();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void clearForBiddenZone()
  {
   ind.forBiddenLow = 0;
   ind.forBiddenHigh = 0;
   ObjectDelete("forBiddenLow");
   ObjectDelete("forBiddenHigh");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForFirstOpen()  //开首单，依赖EMA条件优先，然后依赖 bolling 开双单
  {
   bool IsSucc = false;
   bool isOpenFirst = false;
   bool isExistForbiddenZone = ind.forBiddenLow>0 && ind.forBiddenHigh>0;
   bool isOutsideForbiddenZone =
      (Close[1] > ind.forBiddenHigh || Close[1] < ind.forBiddenLow) &&
      (Bid > ind.forBiddenHigh || Bid < ind.forBiddenLow);
   if(ind.orderCount==0
      && ind.tradingCount==0
      && !isLatestCloseBar()
      && (!isExistForbiddenZone || isOutsideForbiddenZone)
     )  //池子里没有单且符合时间区间
     {
      setNormalFirstOrderLots();
      if(isTradingPeriod()
         && (ind.ATRNum>=ind.MA4ATR
             && ind.ATRNum>=ATR_Level
             && ind.ATRNum<=ATR_Cap
             && ind.ATRNum>ind.ATRNumPrev
            )
        )//符合均线判断的总条件
        {
         if(
            (
               ((ind.emaSignal == 1
                 && (ind.Ema5_1>ind.Ema6_1)
                 && (ind.Ema5_1>ind.Ema5_2 && ind.Ema6_1>ind.Ema6_2)
                 && MathAbs(ind.Ema5_0-ind.Ema6_0)<=Diff_pips*Point

                )
                && (ind.HeiKinBody=="buy" && ind.HeiKinShadow=="buy")
               )

            )
            && (ind.MACD_main>ind.MACD_signal && ind.MACD_main>=MACD_To)

            && !isOpenFirst

         )  // buy：快线大于慢线，且必须是上涨趋势 [1,3]
           {
            IsSucc = open(OP_BUY,Ask,0,0,Blue);
            if(IsSucc)  //open 成功就 reset buyprice
              {
               Print("open succ");
               setFirstOrderParam("buy",Ask,TimeCurrent());
               clearForBiddenZone();
               isOpenFirst = true;
              }
           }
         else
            if(
               (
                  (ind.emaSignal == -1
                   && (ind.Ema5_1<ind.Ema6_1)
                   && (ind.Ema5_1<ind.Ema5_2 && ind.Ema6_1<ind.Ema6_2)
                   && MathAbs(ind.Ema5_0-ind.Ema6_0)<=Diff_pips*Point

                   && (ind.HeiKinBody=="sell" && ind.HeiKinShadow=="sell")

                  )
               )
               && (ind.MACD_main<ind.MACD_signal && ind.MACD_main<=MACD_From)

               && !isOpenFirst
            )  //sell
              {
               IsSucc = open(OP_SELL,Bid,0,0,Red);
               if(IsSucc)
                 {
                  setFirstOrderParam("sell",Bid,TimeCurrent());
                  clearForBiddenZone();
                  isOpenFirst = true;
                 }
              }

        }
      else
         if(Bid>=ind.Bbands1_middle-OpenRangePips*Point
            && Bid<=ind.Bbands1_middle+OpenRangePips*Point
            && ind.Bbands1_middle>ind.Ema7_low
            && ind.Bbands1_middle<ind.Ema7_high
            && shouldBollingTrading(ConsecutiveBars)
           ) //价格达到布林中轨，开 buy 和 sell
           {
            double curBuyTP = Bid+CloseRangePips*Point;
            double curSellTP = Ask-CloseRangePips*Point;
            Print("open scalping order:",ind.Bbands1_middle);
            open(OP_BUY,Ask,0,curBuyTP,Blue);
            open(OP_SELL,Bid,0,curSellTP,Red);
            ind.tradingType = SCALPING;
            isOpenFirst = true;
            clearForBiddenZone();
           }
     }


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setFirstOrderParam(string flag,double orderPrice,datetime orderTime)  //设置首单相关变量
  {
// Print("open firstOrder");
   if(flag == "buy")
     {
      ind.firstFlag = "buy";
      ind.high = orderPrice+ind.hedging_TP;
      ind.low = orderPrice-(ind.hedging_TP+ind.hedging_SL);
     }
   if(flag == "sell")
     {
      ind.firstFlag = "sell";
      ind.low = orderPrice-ind.hedging_TP;
      ind.high = orderPrice+(ind.hedging_TP+ind.hedging_SL);

     }
   ind.firstOpenPrice = orderPrice;
   ind.firstOpenTime = orderTime;
//ind.orderCount = 1;
   createLine("HTPLINE",ind.high,Blue);
   createLine("HSLLINE",ind.low,Red);
   createLine("HopenLine",ind.firstOpenPrice,Plum);
//ObjectDelete(TPLineName);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RoundToTwoDecimalPlaces(double value)
  {
// 将原值先获取三位小数再乘以1000
   double temp = NormalizeDouble(value,3) * 1000;

// 如果不能整除10，说明第三位小数不为零
   if(MathMod(temp, 10) != 0)
     {
      // 向上取整并保留两位小数
      return NormalizeDouble(MathCeil(value * 100.0) / 100.0, 2);
     }
   else
     {
      // 保留两位小数
      return NormalizeDouble(value, 2);
     }
  }

//+------------------------------------------------------------------+
//| 通过前一单 lots 设置当前hedging lots                                |
//+------------------------------------------------------------------+
void setHedingCurLotsByPrevLots(double preLots,int curCount)
  {
   if(preLots==0)  // 前一个lots=0，表示池子里没有数据
     {
      curLots = Lots;
     }
   else
     {
      if(curCount%2==0)
        {
         curLots = RoundToTwoDecimalPlaces(preLots * times);
        }
      else
        {
         curLots =  RoundToTwoDecimalPlaces((R2R+1)/R2R*times*preLots);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setCurLotsOfSafeModeByPrevLots(double preLots)  //safe 单的 lots 设置
  {
   Print("safe mode setLots preLots:",preLots);
   if(preLots==0)  // 前一个lots=0
     {
      curLots = ind.firstSafeLots;
     }
   else
     {
      int idx = -1;
      for(int i=0; i<SafeLimit; i++)
        {
         if(safeLots[i] > preLots)  //找到第一个大于 prelots 的 idx
           {
            idx = i;
            break;
           }
        }
      Print("curIdx=",idx);
      if(idx!=-1)
        {
         curLots = safeLots[idx];
         if(idx==SafeLimit-1)
            ind.isLastSafeOrder = true;
        }
      else  //找不到相应的 lots 则不开仓
        {
         curLots = 0;
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void resetByOrderCount() //重置变量
  {
   if(ind.orderCount==0)  //池子里没有单子，意味着已经ihending结束或者还没有开始，reset各个变量
     {
      ind.orderCount = 0; // heding次数清0
      ind.prevFlag = "";
      ind.firstFlag = "";
      ind.firstOpenPrice = 0;
      ind.firstOpenTime = 0;
      ind.high = 0;
      ind.low = 0;
      ind.prevLots = 0;
      ind.isHashedeing = false;
      ind.tradingType = NORMAL;
      ind.prevOpenPrice = 0;
      ind.firstSL = 0;
      ind.isLastSafeOrder=false;

      ObjectDelete("HSLLINE");
      ObjectDelete("HTPLINE");
      ObjectDelete("HopenLine");
      ObjectDelete(TPLineName);
      ObjectDelete(FirstSLLINE);
     }
   else
     {
      clearForBiddenZone();
     }
  }
//+------------------------------------------------------------------+
//|根据池子里的单子来设置相关变量,包括
//   首单相关，preorder相关，交易类型，hedging_SL/TP,以及单子总数                     |
//+------------------------------------------------------------------+
void setOrderDataByPool()
  {
   int count = 0;
   ind.prevLots = 0;
   ind.prevOpenPrice = 0;
   ind.tradingCount = 0;
   int limit = 0;
   bool isHasHedeing = false;
   ind.tradingType = NORMAL;
   int prevOrderType = -1;
   double curOderLots = 0;
   int curOrderType = -1;
   double curOpenPrice = 0;
   double curOrderLoss = 0;
   datetime curOpenTime = 0;
   double curTP = 0;
   int TPGreater0Count = 0;
   double prevOrderLots = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {

      //如果 没有本系统所交易的仓单时，跳出循环
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;

      ind.tradingCount++;
      //如果 仓单货币对不是当前货币对时，继续选择
      if(OrderSymbol()!=_Symbol)
         continue;

      if(OrderTicket())
        {
         curOderLots = OrderLots();
         curOrderType = OrderType();
         curOpenPrice = OrderOpenPrice();
         curOrderLoss = OrderStopLoss();
         curOpenTime = OrderOpenTime();
         curTP = OrderTakeProfit();
         if(curTP)
           {
            TPGreater0Count++;
           }
         if(prevOrderType == -1)
           {
            prevOrderType = curOrderType;
            prevOrderLots = curOderLots;
           }
         if(count==1) //池子里第二单，若两个挨着的单子type 不同，则 heiding 模式或 scaping，否则顺势加仓
           {
            if(OrderType()!= prevOrderType)
              {
               if(curOderLots==Lots && prevOrderLots==curOderLots)  //如果紧挨着两个 lots 相同且等于initLots，说明是SCALPING;
                 {
                  ind.tradingType = SCALPING;
                 }
               else
                 {
                  isHasHedeing = true;
                  ind.tradingType = HEDGING;
                 }
              }
            else
              {
               ind.tradingType = ADDLOTS;
              }
            prevOrderType = curOrderType;
            prevOrderLots = curOderLots;
           }
         if(count==0)  //池子里最近的单子
           {
            ind.prevFlag = OrderType()==OP_BUY?"buy":OrderType()==OP_SELL?"sell":"";
            ind.prevLots = OrderLots();
            ind.prevOpenPrice = OrderOpenPrice();

           }
         limit++;
         count++;

        }

     }
   if(curOderLots!= Lots && count==1)  //首单 lots 不等于设置 lots，说明是 safe 加仓
     {
      ind.tradingType = SAFELOTS;
     }
   if(count==0)
     {

      ind.hedging_SL = SL*Point;
      ind.hedging_TP = TF*Point;
      // ind.countOfBarsGreaterThanOpen = 0;
      GlobalVariableDel(slCacheKey);
     }
   else
      if(GlobalVariableGet(slCacheKey))
        {
         ind.hedging_SL = GlobalVariableGet(slCacheKey);
         ind.hedging_TP = R2R * ind.hedging_SL;
        }
   if(curOrderType==OP_BUY)
      setFirstOrderParam("buy",curOpenPrice,curOpenTime);
   if(curOrderType==OP_SELL)
      setFirstOrderParam("sell",curOpenPrice,curOpenTime);

   ind.isHashedeing = isHasHedeing;
   ind.firstOrderLoss = curOrderLoss;
   ind.orderCount = count;
   resetByOrderCount();
   setForbiddenZone();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setFirstSLLine()  //设置加仓Mode的止损点
  {
   if(ind.tradingType==ADDLOTS)  //池子里至少有两个单子，且没进入hedeing逻辑，设置止损
     {
      double prevSL = getLine(FirstSLLINE);
      double curSL = 0;
      setTPLine(ind.firstFlag);
      double curTP = getLine(TPLineName);
      if(ind.firstFlag == "buy")
        {
         curSL = curTP-firstOrderSL*Point;

         if((curSL>prevSL || prevSL==0) && curSL<Bid)
           {
            ind.firstSL = curSL;
            Print("firstSLLine:",curSL);
            createLine(FirstSLLINE,curSL,Green);
           }
        }
      if(ind.firstFlag == "sell")
        {
         curSL = curTP+firstOrderSL*Point;

         if((curSL<prevSL || prevSL==0) && curSL>Ask)
           {
            ind.firstSL = curSL;
            Print("firstSLLine:",curSL);
            createLine(FirstSLLINE,curSL,Green);
           }
        }

     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setTPLine(string cmd)
  {
   if(cmd=="buy")
     {
      if(Ask>ind.firstOpenPrice)
        {
         if(Ask>getLine(TPLineName))
           {
            createLine(TPLineName,Ask,Yellow);
           }
        }
     }
   if(cmd == "sell")
     {
      // Print("line:",(OrderOpenPrice()-TPPips*Point));
      if(Bid<ind.firstOpenPrice)
        {
         if(Bid<getLine(TPLineName) || getLine(TPLineName)==0)
           {
            createLine(TPLineName,Bid,Yellow);
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void createLine(string name,double data,color colorValue,int width=1)
  {
   ObjectDelete(name);
   ObjectCreate(name,OBJ_HLINE,0,0,data);
   ObjectSet(name,OBJPROP_COLOR,colorValue);
   ObjectSet(name, OBJPROP_WIDTH,width);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getLine(string name)
  {
   return ObjectGetDouble(0,name,OBJPROP_PRICE,0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSARReverse()  //判断 SAR 反转
  {

   double Spread = NormalizeDouble(SPREAD * MarketInfo(OrderSymbol(), MODE_POINT),Digits);
   double curSAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
   double prevSAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits);
   if(curSAR==0)
     {

      Print("Not enough historical data - please load more candles for the selected timeframe.");

      return false;

     }
   if((OrderType() == OP_BUY) && curSAR>Ask)
      return true;
   if((OrderType() == OP_SELL) && curSAR<Bid)
      return true;
   return false;

  }
//+------------------------------------------------------------------+
//|对首单进行止盈和止损的操作                                            |
//+------------------------------------------------------------------+
void TrailingFirstOrder()
  {
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      //如果 仓单货币对不是当前货币对时，继续选择
      if(OrderSymbol()!=_Symbol)
         continue;
      string Instrument = OrderSymbol();
      double curProfit = OrderProfit()+OrderSwap()-OrderCommission();
      double curTakeP = OrderTakeProfit();
      if((ind.firstOrderLoss!=0 || curTakeP!=0)
         && ind.orderCount==2 && OrderLots()==Lots
         && (ind.tradingType==HEDGING || ind.tradingType==ADDLOTS)
        )  //如果存在第二单(heiding 和顺势加仓mode)，则需要把首单设置的 loss,tp resign 0
        {
         bool res = OrderModify(OrderTicket(),OrderOpenPrice(),0,0,0,Blue);
         Print("Modify",OrderTicket(),",reason:reset firstSL/TP 0", ",SL:0",",res:",res,",tradingtype:",ind.tradingType);
         break;
        }
      if(ind.orderCount==1 && OrderLots()==Lots)  //只有首单的情况下
        {
         if(curTakeP!=0)  //首单有止盈说明是 SCRPING 的开单，不会设置止损
           {
            bool res = false;
            if(OrderType()==OP_BUY && curTakeP>=OrderOpenPrice()+firstOrderTP*Point)
              {
               res = OrderModify(OrderTicket(),OrderOpenPrice(),0,0,0,Blue);
               Print("Modify",OrderTicket(),",reason:reset TakeProfit 0", ",TP:0",",res:",res);
              }
            if(OrderType()==OP_SELL && curTakeP<=OrderOpenPrice()-firstOrderTP*Point)
              {
               res = OrderModify(OrderTicket(),OrderOpenPrice(),0,0,0,Red);
               Print("Modify",OrderTicket(),",reason:reset TakeProfit 0", ",TP:0",",res:",res);
              }


            break;
           }
         else
            if(curProfit>0)
              {
               double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
               double SLPrice = NormalizeDouble(OrderStopLoss(), Digits);

               double Spread = NormalizeDouble(SPREAD * MarketInfo(Instrument, MODE_POINT),Digits);
               ind.OpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime()); //当前 bar 和开盘时候的 bar 相差几个 bar
               double SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
               double curTP = getLine(TPLineName);
               if(SLBySAR==0)
                 {

                  Print("Not enough historical data - please load more candles for the selected timeframe.");

                  return;

                 }
               //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
               if((OrderType() == OP_BUY))
                 {
                  double curSLPrice = 0;
                  string curSLReason = "";
                  double curSARSL = NormalizeDouble(SLBySAR-Spread,Digits);
                  if(curSARSL<Low[0]) //设置SAR止损.TODO:设置止损跟随
                    {
                     if((curSARSL>SLPrice || SLPrice == 0) && curSARSL<Bid)
                       {
                        if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)<Low[1])|| ind.OpenBarShift==0) //前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
                          {
                           curSLPrice = curSARSL;
                           curSLReason = "SAR";
                          }
                       }

                    }
                  if((curSLPrice>SLPrice || SLPrice==0) && curSLPrice>OrderOpenPrice())
                    {
                     bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Blue);
                     Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", bid:",Bid);
                    }


                 }
               if((OrderType() == OP_SELL))
                 {
                  double curSLPrice = 0;
                  string curSLReason = "";
                  double curSARSL = NormalizeDouble(SLBySAR+Spread,Digits);
                  if((curSARSL>High[0])) //SAR 位置准确优先 Sar 设置
                    {
                     if((curSARSL<SLPrice || SLPrice==0) && Ask<curSARSL)
                       {
                        if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)>High[1])|| ind.OpenBarShift==0) //前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
                          {
                           curSLPrice = curSARSL;
                           curSLReason = "SAR";
                          }
                       }
                    }
                  if((curSLPrice<SLPrice || SLPrice==0) && curSLPrice>Ask && curSLPrice<OrderOpenPrice())
                    {
                     bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Red);
                     Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", Ask:",Ask);
                    }
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForFollowingOpen()  //顺势加仓
  {
   if(ind.orderCount>=1 && (ind.tradingType==NORMAL || ind.tradingType==ADDLOTS))
     {
      if(ind.firstFlag=="buy" && Bid>=ind.prevOpenPrice+firstOrderTP*Point && (ind.tradingType==NORMAL || ind.tradingType == ADDLOTS) && ind.orderCount<=TPCount)
        {
         curLots = ind.prevLots*percentOfAddLots<0.01?0.01:ind.prevLots*percentOfAddLots;
         if(open(OP_BUY,Ask,0,0,Blue))
           {
            ind.tradingType = ADDLOTS;
            setFirstSLLine();

           }
        }
      if(ind.firstFlag=="sell" && Bid<=ind.prevOpenPrice-firstOrderTP*Point && (ind.tradingType==NORMAL || ind.tradingType == ADDLOTS) && ind.orderCount<=TPCount)
        {
         curLots = ind.prevLots*percentOfAddLots<0.01?0.01:ind.prevLots*percentOfAddLots;
         if(open(OP_SELL,Bid,0,0,Red))
           {
            ind.tradingType = ADDLOTS;
            setFirstSLLine();
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openHedeingOrder(int cmd,double price,double sl,double tp,color c)  //开 hedeing单
  {
   setHedingCurLotsByPrevLots(ind.prevLots,ind.orderCount);
   if(open(cmd,price,sl,tp,c))
     {
      ind.isHashedeing = true;
      ind.tradingType = HEDGING;
      ind.prevFlag = cmd==OP_BUY?"buy":"sell";
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openSafeOrder(int cmd,double price,double sl,double tp,color c,bool isFirstOrder) //开safe 单
  {
//calculate curLots
   if(isFirstOrder)
     {
      setCurLotsOfSafeModeByPrevLots(0);
     }
   else
     {
      setCurLotsOfSafeModeByPrevLots(ind.prevLots);
     }

   if(curLots>0 && open(cmd,price,sl,tp,c))
     {
      ind.isHashedeing = false;
      ind.tradingType = SAFELOTS;
      ind.prevFlag = cmd==OP_BUY?"buy":"sell";
      Print("delete orders, preflag:",cmd,",curLots:",curLots);
      deleteOrdersExceptLastOne(); //删除所开单之外的所有单子
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void deleteOrdersExceptLastOne() //删除除最后一单所有单
  {
   long lastTicket = 0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      //如果 仓单货币对不是当前货币对时，继续选择
      if(OrderSymbol()!=_Symbol)
         continue;
      Print("orderTicket:",OrderTicket(),",pos:",j);
      if(lastTicket==0)
        {
         lastTicket = OrderTicket();
         Print("lastTicket:",lastTicket);
        }
      if(OrderTicket()==lastTicket)
         continue;
      if(OrderType()==OP_BUY)
        {
         Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
        }
      if(OrderType()==OP_SELL)
        {
         Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openAdditionalOrder(int cmd,double price,double sl,double tp,color c,bool isGreaterMax)
  {
   if(isGreaterMax)  //已经是最大 heideing 数，开safe 首单
     {
      openSafeOrder(cmd,price,sl,tp,c,true);
     }
   else
     {
      openHedeingOrder(cmd,price, sl, tp,c);
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForSafeOrderOpen()
  {
//safeOrder 开单判断
   if(ind.tradingType==SAFELOTS && ind.orderCount==1) //开safe 单
     {

      if(ind.prevFlag == "buy" &&  Bid<=ind.prevOpenPrice-ind.hedging_SL+SPREAD*Point && Bid>=ind.prevOpenPrice-ind.hedging_SL-SPREAD*Point)
        {

         openSafeOrder(OP_SELL,Bid, 0, 0,Red,false);
        }
      if(ind.firstFlag == "sell" &&  Bid>=ind.prevOpenPrice+ind.hedging_SL-SPREAD*Point && Bid<=ind.prevOpenPrice+ind.hedging_SL+SPREAD*Point)
        {

         openSafeOrder(OP_BUY,Bid, 0, 0,Blue,false);
        }

     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForOpen()
  {
   if(!isOpenAutoClose || ind.profitFromIdxDay>=0 || (isOpenAutoClose && ind.profitFromIdxDay<0 && MathAbs(ind.profitFromIdxDay)<MathAbs(LossPerDay)))
     {
      checkForFirstOpen(); //检测首单
     }
   checkForFollowingOpen(); //检测首单顺势加仓单
   checkForSafeOrderOpen(); //检测safe单

   if(ind.orderCount>=1 && (ind.tradingType==NORMAL || ind.tradingType==HEDGING)) //如果池子里有开单
     {
      bool isGreaterMaxLimit = ind.orderCount>MAXLIMIT;
      if(ind.firstFlag == "buy") //首单是buy单的hedeing
        {
         if(ind.prevFlag=="buy" && Bid<=ind.firstOpenPrice-ind.hedging_SL+SPREAD*Point && Bid>=ind.firstOpenPrice-ind.hedging_SL-SPREAD*Point)  //上一单是buy，当前bid小于设置的SL,hedeing
           {
            openAdditionalOrder(OP_SELL,Bid, 0, 0,Red,isGreaterMaxLimit);
           }
         else
            if(ind.prevFlag == "sell" && Bid>=ind.firstOpenPrice-SPREAD*Point && Bid<=ind.firstOpenPrice+SPREAD*Point)
              {
               openAdditionalOrder(OP_BUY,Ask,0,0,Blue,isGreaterMaxLimit);
              }
        }
      if(ind.firstFlag == "sell")
        {

         if((ind.prevFlag == "sell") && Bid>=ind.firstOpenPrice+ind.hedging_SL-SPREAD*Point && Bid<=ind.firstOpenPrice+ind.hedging_SL+SPREAD*Point)
           {
            openAdditionalOrder(OP_BUY,Ask,0,0,Blue,isGreaterMaxLimit);

           }
         else
            if((ind.prevFlag == "buy") && Bid<=ind.firstOpenPrice+SPREAD*Point && Bid>=ind.firstOpenPrice-SPREAD*Point)
              {
               openAdditionalOrder(OP_SELL,Bid, 0, 0,Red,isGreaterMaxLimit);

              }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkProfitByDay(int indexDay)
  {
   const datetime timeStart=iTime(_Symbol,PERIOD_D1,indexDay),
                  timeEnd = TimeCurrent();
   double result=0.;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         //filter by OrderSymbol() and OrderMagicNumber() here
         if(OrderCloseTime()<timeStart || OrderCloseTime()>=timeEnd)
            continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
        }
     }
   for(int j=0; j<OrdersTotal(); j++)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      if(OrderOpenTime()<timeStart)
         continue;
      result+=OrderProfit() + OrderCommission() + OrderSwap();
     }
   ind.profitFromIdxDay = NormalizeDouble(result,2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getCurOrderProfit()
  {
   double result = 0;
   for(int i=0; i<OrdersTotal(); i++) //get trading profit;
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         return false;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderSymbol()!=_Symbol)
         continue;
      result+=OrderProfit() + OrderCommission() + OrderSwap();
     }
   for(int j=OrdersHistoryTotal()-1; j>=0; j--) //get history profit
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_HISTORY))
        {
         if(OrderSymbol()!=_Symbol)
            break;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
         if(OrderLots() == Lots)
            break;
        }
     }
   return result;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeOrderForProfit()  //hedging mode 或 只有首单的模式会触发检测利润平仓机制
  {
//Print((int)(TimeCurrent()-ind.firstOpenTime),ind.firstOpenTime);
   if(
      (ind.tradingType==NORMAL && ind.orderCount==1 && getCurTimeSnds()>preCloseSnds)
      ||
      ((ind.tradingType==HEDGING && ind.orderCount>1) &&
       ((getCurTimeSnds()>preCloseSnds) || (ind.orderCount-1>MAXLIMIT/2+1) || ((int)(TimeCurrent()-ind.firstOpenTime)>=CheckHours*60*60))
      )
   )  //大于开始检查时间后 or hededing mode 下至少有两单且hedeing 次数大于最大hedging次数 一半以上，或者距离开仓时间＞设置值，检查池子里的利润
     {
      //Print((int)(TimeCurrent()-ind.firstOpenTime),ind.firstOpenTime);
      double result = 0;
      for(int i=0; i<OrdersTotal(); i++)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
            break;
         //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
         if(OrderSymbol()!=_Symbol)
            continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
        }
      if(result>=targetProfit)
        {
         Print("closeALL because of targetProfit");
         closeAllOrders();

        }
     }
   if(ind.tradingType==NORMAL && ind.orderCount==1)  //首单
     {
      if(isNewBar() && ind.countOfBarsGreaterThanOpen==0)  //当前 bar 是新 bar且没有计算过count，根据当前 bar 和开仓 bar 的差值，计算出count
        {
         for(int i=0; i<OrdersTotal(); i++)
           {
            if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
               break;
            //如果 仓单货币对不是当前货币对时，继续选择
            if(OrderSymbol()!=_Symbol)
               continue;
            int firstOpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime());

            if(firstOpenBarShift>=firstOrderCalBar+1)
              {
               ind.countOfBarsGreaterThanOpen = getCountOfBarsGreaterThanOpen(ind.firstOpenPrice,OrderType());
              }

           }
        }

      if(ind.countOfBarsGreaterThanOpen<firstOrderMinBars && ind.countOfBarsGreaterThanOpen>0)
        {
         double result = 0;
         for(int i=0; i<OrdersTotal(); i++)
           {
            if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
               break;
            //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
            if(OrderSymbol()!=_Symbol)
               continue;
            result+=OrderProfit() + OrderCommission() + OrderSwap();
            if(result>=0)
              {
               Print("closeALL because of firstOrderMinBars:",ind.countOfBarsGreaterThanOpen);
               closeAllOrders();
              }
           }

        }
     }
//if(ind.tradingType==SAFELOTS && ind.orderCount==1){
// if(getCurOrderProfit()>=targetProfit){
//    Print("closeALL because of safe order targetProfit");
// }
//}
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getCountOfBarsGreaterThanOpen(double openPrice,int cmd)
  {
   int count = 0;
   for(int i=1; i<firstOrderCalBar+1; i++)
     {
      double curTripleValue = NormalizeDouble((Open[i]+High[i]+Low[i])/3,Digits);
      if(cmd == OP_BUY && curTripleValue>openPrice)
        {
         count++;
        }
      else
         if(cmd == OP_SELL && curTripleValue<openPrice)
           {
            count++;
           }
     }
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkForClose()
  {
   bool closeAll = false;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderSymbol()!=_Symbol)
         continue;
      if((ind.tradingType==HEDGING && ind.orderCount>1)
         || (ind.tradingType==SAFELOTS && ind.orderCount==1))  //有hedeing 单，说明进入了hedging or safe流程
        {

         if(OrderType()==OP_BUY && (Bid>=ind.high))
           {
            Print("ticket:",OrderTicket(),",curTP:",ind.high,",curSL:",ind.low,",mode:",ind.tradingType,",pos:",i,",count:",ind.orderCount);
            closeAll = true;
            break;
           }
         if(OrderType()==OP_SELL && (Ask<=ind.low))
           {
            Print("ticket:",OrderTicket(),",curTP:",ind.low,",curSL:",ind.high,",mode:",ind.tradingType,",pos:",i,",count:",ind.orderCount);
            closeAll = true;
            break;
           }
         if(ind.tradingType==SAFELOTS && ind.orderCount==1 && ind.isLastSafeOrder)
           {
            if(OrderType()==OP_BUY && Bid<=OrderOpenPrice()-ind.hedging_SL)
              {
               Print("ticket:",OrderTicket(),",curSL:",OrderOpenPrice()-ind.hedging_SL,",mode:",ind.tradingType,",pos:",i,",count:",ind.orderCount);
               closeAll = true;
               break;
              }
            else
               if(OrderType()==OP_SELL && Ask>=OrderOpenPrice()+ind.hedging_SL)
                 {
                  Print("ticket:",OrderTicket(),",curSL:",OrderOpenPrice()+ind.hedging_SL,",mode:",ind.tradingType,",pos:",i,",count:",ind.orderCount);
                  closeAll = true;
                  break;
                 }
           }
        }

      if(ind.tradingType==ADDLOTS &&  ind.orderCount>1) //顺势加仓，如果大于一个单
        {
         if(OrderType()==OP_BUY && Bid<=ind.firstSL)
           {
            Print("ticket:",OrderTicket(),",firstSL:",ind.firstSL,",Bid:",Bid);
            closeAll = true;
            break;
           }
         if(OrderType()==OP_SELL && Ask>=ind.firstSL)
           {
            Print("ticket:",OrderTicket(),",firstSL:",ind.firstSL,",Ask:",Ask);
            closeAll = true;
            break;
           }
        }
      if(ind.tradingType == NORMAL && ind.orderCount==1)
        {
         int curBarIdx = iBarShift(NULL,Timeframe,OrderOpenTime());

         if((OrderProfit() + OrderCommission() + OrderSwap())>0 && IsSARReverse())
           {
            //首单并且是当前利润大于0，若是 SAR 反转就平仓
            closeAll = true;
            break;
           }
         if(curBarIdx>=0 && curBarIdx<=maxCloseBarFromStart)
           {
            if(OrderType()==OP_BUY && Bid<=OrderOpenPrice()-ind.hedging_SL+SPREAD*Point && Bid>=OrderOpenPrice()-ind.hedging_SL-SPREAD*Point)
              {
               Print("close order because the order meet hedging line between start to max");
               closeAll = true;
               break;
              }
            else
               if(OrderType() == OP_SELL && Bid>=OrderOpenPrice()+ind.hedging_SL-SPREAD*Point && Bid<=OrderOpenPrice()+ind.hedging_SL+SPREAD*Point)
                 {
                  closeAll = true;
                  Print("close order because the order meet hedging line between start to max");
                  break;
                 }

           }
        }

     }
   if(closeAll)
     {
      Print("closeALL becase of TP/SL");
      closeAllOrders();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllOrders()
  {
   if(ind.tradingType==HEDGING)  //hedeing mode 需要倒序平仓
     {
      for(int j=OrdersTotal()-1; j>=0; j--)
        {
         Print("Original pos:",j,",orderTicket:",OrderTicket());
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false)
            continue;
         //如果 仓单货币对不是当前货币对时，继续选择
         if(OrderSymbol()!=_Symbol)
            continue;
         Print("orderTicket:",OrderTicket(),",pos:",j);
         if(OrderType()==OP_BUY)
           {
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));

           }
         if(OrderType()==OP_SELL)
           {
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
           }
        }
     }
   else  //顺势加仓 mode，正序平仓
     {
      for(int j=0; j<OrdersTotal(); j++)
        {
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false)
            continue;
         //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
         if(OrderSymbol()!=_Symbol)
            continue;
         Print("orderTicket:",OrderTicket(),",pos:",j);
         if(OrderType()==OP_BUY)
           {
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));
            j--;

           }
         if(OrderType()==OP_SELL)
           {
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
            j--;
           }
        }
     }
   setOrderDataByPool(); //after close ,need to reSet relevant Order Data
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

   setOrderDataByPool();

   setFirstSLLine();
   closeOrderForProfit();
   checkForClose();

//Print("get:",GlobalVariableGet("hedging_SL"),",sl:",ind.hedging_SL);
   if(vSpread<=SPREAD  && Period()==Timeframe)  //当前市场的点差小于设置的点差才进行计算
     {
      RefreshRates();
      CalcInd();

      checkProfitByDay(0);
      TrailingFirstOrder();
      checkForOpen();
      Comment("profit:",ind.profitFromIdxDay
              ,"\n prevLots:",ind.prevLots,
              "\n orderCount:", ind.orderCount,
              "\n prevFlag:",ind.prevFlag,
              "\n mode:",ind.tradingType,
              "\n ATR:",ind.ATRNum,
              "\n MA4ATR:",ind.MA4ATR
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
