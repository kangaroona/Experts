//+------------------------------------------------------------------+
//|                                                   hedeing_v2.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
input int      TF=500;
input int      SL=250;
input int SPREAD = 100;
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
input DF Timeframe = M5; 
input double   times=1.1;
input double Lots=0.1;
input int MAXLIMIT = 5; //Heiding max limit
input int TPPips = 2000;
input double TPPercent = 0.8;
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
input double PSARMax = 0.2;                       // PSAR Max
extern string AverageBar="----------------AverageBarForProfitSL----------------------";
input int BarPeriod = 20;                         //average bars
input double percentOfSL = 2;
extern string BBand="----------------BBand----------------------";
input int Bbands_Period = 9;
input int Bbands_Deviation=1;
input int Bbands_Deviation_SL = 2;
extern string Loss="----------------Loss----------------------";
input bool isOpenAutoClose = true;
input double LossPerDay = 100;
struct Indicator{
   double emaArr[4][3];
   double Ema5_1;
   double Ema6_1;
   double Ema5_2;
   double Ema6_2;
   bool isNewBar;
   int emaSignal;
   double Bbands1_up;
   double Bbands1_down;
   double Bbands1_middle;
   double barAverage;
   double Weight1;
   double Weight2;
   double profitFromIdxDay;
   int prevEMACountOfSell;
   int prevEMACountOfBuy;
   int OpenBarShift;
   int orderCount;
   double high;
   double low;
   string firstFlag;
   double firstOpenPrice;
   string prevFlag;
   double prevLots;
   
};
Indicator ind;
int emaperiod[];
int closeOrder[];
long prevBar=0;
bool isFirst = true;
double curLots = Lots;
double R2R = TF/SL;
string TPLineName = "TPLINE";

#define COMMENT  "Hedeing_20240211_"+IntegerToString(Timeframe) 
#define MAGICMA  20240401
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   ind.isNewBar = true;
   for(int i =0;i<4;i++){
      for(int j=0;j<3;j++){
         ind.emaArr[i][j] = 0;
      }
   }
   ArrayResize(emaperiod,4);
   ArrayResize(closeOrder,MAXLIMIT+1);
   emaperiod[0] = EMA1;
   emaperiod[1] = EMA2;
   emaperiod[2] = EMA3;
   emaperiod[3] = EMA4;
   ind.prevEMACountOfSell = 0;
   ind.prevEMACountOfSell = 0;
   ind.orderCount = 0;
   ind.firstFlag = "";
   ind.firstOpenPrice = 0;
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
   
   Print("EA运行结束，已经卸载" );
   
  }
bool isNewBar(){
   long curBar = SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(curBar!=prevBar){
      prevBar = curBar;
      return true;
   }
   return false;

}
bool open(int cmd,double price,double sl,double tf,color arrColor){
      //ind.single = cmd==OP_BUY?"buy":"sell";
      Print("lots:",curLots,",orderCount:",ind.orderCount,",firstFlag:",ind.firstFlag,"prevLots:",ind.prevLots);
      int res = OrderSend(Symbol(), cmd, curLots, price, 5,sl, tf,  COMMENT,MAGICMA,0,arrColor);
      if(res<0){
         Print("open fail");
         return false;
      }
      return true;  
}
double getAverageByPeriod(int period,double curAverage){
   if(ind.isNewBar || curAverage==0){
      double sum = 0;
      
      for(int i=1; i<=period; i++){
         sum+=High[i]-Low[i];
      }
      return NormalizeDouble(sum/period,Digits);
   }
   return curAverage;
}
void CalcInd(){
   ind.isNewBar = isNewBar();
   ind.barAverage = getAverageByPeriod(BarPeriod,ind.barAverage);
   setOrderCount();
   if(ind.isNewBar){
      int curEmaSignal = 0;
      ind.emaSignal = 0;
      //Print("emaperiod=",ArraySize(emaperiod));
      for(int i=0;i<ArraySize(emaperiod);i++){
         for(int j=0;j<3;j++){
            ind.emaArr[i][j] = NormalizeDouble(iMA(NULL,Timeframe,emaperiod[i],0,EMAMethod,EMAPrice,j+1),Digits);
         }
      }
      int zeroCount = 0;
      for(int k=0;k<ArraySize(emaperiod);k++){
         double EMA1OfPeriod = ind.emaArr[k][0];
         double EMA2OfPeriod = ind.emaArr[k][1];
         if(EMA1OfPeriod>EMA2OfPeriod){
            curEmaSignal++;
         }
         if(EMA1OfPeriod<EMA2OfPeriod){
            curEmaSignal--;
         }
         if(EMA1OfPeriod == EMA2OfPeriod){
            zeroCount++;
         }
      }
      //Print("zeroCount=",zeroCount,",curEmaSignal=",curEmaSignal);
      if(zeroCount<2){
         if(curEmaSignal>=2) ind.emaSignal = 1;
         if(curEmaSignal<=-2) ind.emaSignal = -1;
      } 
      ind.Ema5_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema6_1 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,1),Digits);
      ind.Ema5_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,2),Digits);
      ind.Ema6_2 = NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,2),Digits);
      ind.Bbands1_up = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_UPPER,1),Digits);
      ind.Bbands1_down = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_LOWER,1),Digits);
      ind.Bbands1_middle = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,1),Digits);
      ind.Weight1 = NormalizeDouble((Low[1]+High[1]+Close[1]+Open[1])/4,Digits);
      ind.Weight2 = NormalizeDouble((Low[2]+High[2]+Close[2]+Open[2])/4,Digits);
      setCountOfEMA();
   }
}
//池子里是否有单子

void checkForFirstOpen(){ //开首单，依赖EMA条件
   bool IsSucc = false;
   if(ind.orderCount==0){ //
      if((ind.emaSignal == 1 && (ind.Ema5_1>ind.Ema6_1 && Close[1]>ind.Ema5_1) && (ind.Ema5_1>ind.Ema5_2 && ind.Ema6_1>ind.Ema6_2) && ind.prevEMACountOfBuy>=1 && ind.prevEMACountOfBuy<=3) ){ // buy：快线大于慢线，且必须是上涨趋势 [1,3]
         IsSucc = open(OP_BUY,Ask,0,0,Blue);
         if(IsSucc){ //open 成功就 reset buyprice
            setFirstOrderParam("buy",Ask);
         }   
      }
      if(ind.emaSignal == -1 && (ind.Ema5_1<ind.Ema6_1 && Close[1]<ind.Ema5_1)  && (ind.Ema5_1<ind.Ema5_2 && ind.Ema6_1<ind.Ema6_2) && ind.prevEMACountOfSell>=1 && ind.prevEMACountOfSell<=3){ //sell
         IsSucc = open(OP_SELL,Bid,0,0,Red);
         if(IsSucc){
            setFirstOrderParam("sell",Bid);
         }  
      }
   }
}
void setFirstOrderParam(string flag,double orderPrice){ //设置首单相关变量
   //Print("flag:",flag);
   if(flag == "buy"){
      ind.firstFlag = "buy";
      ind.high = orderPrice+TF*Point;
      ind.low = orderPrice-(SL+TF)*Point;
   }
   if(flag == "sell"){
      ind.firstFlag = "sell";
     ind.low = orderPrice-TF*Point;
     ind.high = orderPrice+(SL+TF)*Point;
      
   }
   ind.firstOpenPrice = orderPrice;
   createLine("HTPLINE",ind.high,Blue);
   createLine("HSLLINE",ind.low,Red);
   createLine("HopenLine",ind.firstOpenPrice,Plum);
   //ObjectDelete(TPLineName);
}
void setCurLots(double preLots,int curCount){
   if(preLots==0){ // 前一个lots=0，表示池子里没有数据
      curLots = Lots;
   }
   else{
      if(curCount%2==0){
         curLots = NormalizeDouble(preLots * times,3);
      }
      else{  
         curLots =  NormalizeDouble((R2R+1)/R2R*times*preLots,3);
      }
   }
}
void resetByOrders(){//重置变量
   if(ind.orderCount==0){ //池子里没有单子，意味着已经ihending结束或者还没有开始，reset各个变量
      ind.orderCount = 0; // heding次数清0
      ind.prevFlag = "";
      ind.firstFlag = "";
      ind.firstOpenPrice = 0;
      ind.high = 0;
      ind.low = 0;
      ind.prevLots = 0;
      ObjectDelete("HSLLINE");
      ObjectDelete("HTPLINE");
      ObjectDelete("HopenLine");
      ObjectDelete(TPLineName);
   }
}
void setOrderCount(){ //根据池子里的单子来设置相关变量,包括curLots,首单开仓价，以及单子总数
   int count = 0; 
   ind.prevLots = 0;
   int limit = 0;
   for(int i=OrdersTotal()-1;i>=0;i--)
    {
      //如果 没有本系统所交易的仓单时，跳出循环
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      if(OrderTicket()){
         if(count==0){ //池子里最近的单子
            ind.prevFlag = OrderType()==OP_BUY?"buy":OrderType()==OP_SELL?"sell":"";
            ind.prevLots = OrderLots();

         }
         if(OrderLots() == Lots){
            if(OrderType()==OP_BUY) setFirstOrderParam("buy",OrderOpenPrice());
            if(OrderType()==OP_SELL) setFirstOrderParam("sell",OrderOpenPrice());
            
         }
         limit++;
         count++;

      }

    }
    setCurLots(ind.prevLots,limit);
    ind.orderCount = count;
}
void createLine(string name,double data,color colorValue,int width=1){
   ObjectDelete(name);
   ObjectCreate(name,OBJ_HLINE,0,0,data);
   ObjectSet(name,OBJPROP_COLOR,colorValue);
   ObjectSet(name, OBJPROP_WIDTH,width);
}
void setTPLine(int cmd){
   if(cmd==OP_BUY){
      if(Ask>=(OrderOpenPrice()+TPPips*Point)){
         if(Ask>getLine(TPLineName)){
            createLine(TPLineName,Ask,Yellow);
         }
      }
   }
   if(cmd == OP_SELL){
     // Print("line:",(OrderOpenPrice()-TPPips*Point));
      if(Bid<=(OrderOpenPrice()-TPPips*Point))
      {
         if(Bid<getLine(TPLineName) || getLine(TPLineName)==0){
            createLine(TPLineName,Bid,Yellow);
         }
      }
   }
   
}
double getLine(string name){
   return ObjectGetDouble(0,name,OBJPROP_PRICE,0);
}
void TrailingFirstOrder(){
   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      string Instrument = OrderSymbol();
      double curProfit = OrderProfit()+OrderSwap()-OrderCommission();
      if(ind.orderCount==1 && curProfit>0 && OrderLots()==Lots){ //只有首单的情况下，只做盈利止损
         double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
         double SLPrice = NormalizeDouble(OrderStopLoss(), Digits);

         double Spread = NormalizeDouble(SPREAD * MarketInfo(Instrument, MODE_POINT),Digits);
         ind.OpenBarShift=iBarShift(NULL,Timeframe,OrderOpenTime()); //当前 bar 和开盘时候的 bar 相差几个 bar
         double SLBySAR = NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 0),Digits);
         setTPLine(OrderType());
         double curTP = getLine(TPLineName);
         double curBbands_up = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation_SL,0,EMAPrice,MODE_UPPER,0),Digits);
         double curBbands_down = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation_SL,0,EMAPrice,MODE_LOWER,0),Digits);
        // double Bbands1_middle = NormalizeDouble(iBands(NULL,Timeframe,Bbands_Period,Bbands_Deviation,0,EMAPrice,MODE_MAIN,1),Digits);
         if (SLBySAR==0)
         {
         
               Print("Not enough historical data - please load more candles for the selected timeframe.");
         
               return;
         
         }
        //止损优先 sar，如果 SAR 不符合条件，再检查重心比较是否符合条件，来设置止损
         if ((OrderType() == OP_BUY)){
             double curSLPrice = 0;
             string curSLReason = "";
             double curSARSL = NormalizeDouble(SLBySAR-Spread,Digits);  
             if(curSARSL<Low[0]){//设置SAR止损.TODO:设置止损跟随
               if((curSARSL>SLPrice || SLPrice == 0) && curSARSL<Bid){
                  if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)<Low[1])|| ind.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
                     curSLPrice = curSARSL;
                     curSLReason = "SAR";
                  }
               }
               
             }
            //if((curBbands_down>curSLPrice || curSLPrice == 0) && curBbands_down<Bid){
            //   curSLPrice = curBbands_down;
            //   curSLReason = "BB";
            //}
             if(Bid>OrderOpenPrice() && curProfit>0){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bar倍数来设置
                double diffPrice = MathAbs(NormalizeDouble(Bid-OrderOpenPrice(),Digits));
                double percent = NormalizeDouble((diffPrice/ind.barAverage),Digits);
      
                if(diffPrice>ind.barAverage && percent>=percentOfSL && ind.Weight1<ind.Weight2){ 
                   double curSL =  NormalizeDouble((OrderOpenPrice()+diffPrice/3),Digits);    
                   if(curSL>curSLPrice && curSL<Bid){
                      //createLine("SLline",curSL,Plum);
                      curSLPrice = curSL;
                      curSLReason = "profit SL";
                   }
      
                }
             }
             if(curTP>OrderOpenPrice()){
               double curTPLineSL = NormalizeDouble(OrderOpenPrice()+(curTP-OrderOpenPrice())*TPPercent,Digits);
               if(ind.Weight1<ind.Weight2 && Open[1]>Close[1]){//重心下降且是阴柱
                  curTPLineSL = NormalizeDouble(OrderOpenPrice()+MathAbs((curTP-OrderOpenPrice()))*(1-TPPercent),Digits);
               }
               if(curTPLineSL>curSLPrice && curTPLineSL<Bid){
                  curSLPrice = curTPLineSL;
                  curSLReason = "TPLINE SL";
               }
             }
             if((curSLPrice>SLPrice || SLPrice==0) && curSLPrice>OrderOpenPrice()){
               bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Blue);
               Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", bid:",Bid);
             }
             
      
         }
         if((OrderType() == OP_SELL)){
            double curSLPrice = 0;
            string curSLReason = "";
            double curSARSL = NormalizeDouble(SLBySAR+Spread,Digits); 
            if((curSARSL>High[0])){//SAR 位置准确优先 Sar 设置     
               if((curSARSL<SLPrice || SLPrice==0) && Ask<curSARSL){
                  if((Time[0]>=OrderOpenTime() && NormalizeDouble(iSAR(NULL, Timeframe, PSARStep, PSARMax, 1),Digits)>High[1])|| ind.OpenBarShift==0){//前一 bar 的 sar 不正确的话，当前 bar 不是用 sar 设置，避免 SAR 反转出错
                     curSLPrice = curSARSL;
                     curSLReason = "SAR";
                     //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSARSL,0,0,Red);
                     //Print("Modify order:","reason:SAR",OrderTicket(),",PrevSL:",SLPrice,",SL:",curSARSL,",SAR:",SLBySAR,",res:",res,",Ask:",Ask);
                  }
                }
            }
            //if((curBbands_up<curSLPrice || curSLPrice == 0) && curBbands_up>Ask){
            //   curSLPrice = curBbands_up;
            //   curSLReason = "BB";
            //   //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curBbands_up,0,0,Blue);
            //   //Print("Modify order:",OrderTicket(),",reason:BB,SL:",curBbands_up,",SL:",SLPrice);
            //}
             
            if(Ask<OrderOpenPrice() && curProfit>0){
      
               double diffPrice = MathAbs(NormalizeDouble(OrderOpenPrice()-Ask,Digits));
      
               double percent = NormalizeDouble((diffPrice/ind.barAverage),Digits);
      
                if(diffPrice>ind.barAverage && percent>=percentOfSL && ind.Weight1>ind.Weight2){ //盈利情况下的止损设置，现在主要针对的是价差大于平均 bbar 的情况且暂时反转
                   double curSL =  NormalizeDouble((OrderOpenPrice()- diffPrice/3),Digits);
                      if((curSL<curSLPrice || curSLPrice == 0) && curSL>Ask){
                                 //createLine("SLline",curSL,Plum);
                        curSLPrice = curSL;
                        curSLReason = "profit SL";
                        //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSL,0,0,Red);
                        //Print("Modify",OrderTicket(),",reason:profit SL","percent:",percent," SL:",curSL,",res:",res,", Ask:",Ask);
                      }
      
                }
             }
             if((curTP<OrderOpenPrice()&& curTP>0) && ind.OpenBarShift>=1){
               double curTPLineSL = NormalizeDouble(OrderOpenPrice()-MathAbs((curTP-OrderOpenPrice()))*TPPercent,Digits);
               if(ind.Weight1>ind.Weight2 && Open[1]<Close[1]){//重心升高，则如果>ASK 设置止损，否则直接按照现价平仓
                  curTPLineSL = NormalizeDouble(OrderOpenPrice()-MathAbs((curTP-OrderOpenPrice()))*0.8,Digits);
               }
               if((curTPLineSL<curSLPrice || curSLPrice==0)&& curTPLineSL>Ask){
                   curSLPrice = curTPLineSL;
                   curSLReason = "TPLine SL";
                   //bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curTPLineSL,0,0,Blue);
                   //Print("Modify",OrderTicket(),",reason:TPLine SL"," SL:",curTPLineSL,",res:",res,", bid:",Bid);
               }
             }
             if((curSLPrice<SLPrice || SLPrice==0) && curSLPrice>Ask && curSLPrice<OrderOpenPrice()){
               bool res = OrderModify(OrderTicket(),OrderOpenPrice(),curSLPrice,0,0,Red);
               Print("Modify",OrderTicket(),",reason:",curSLReason,", SL:",curSLPrice,",res:",res,", Ask:",Ask);
             }
         }
      }
   }
}
void checkForOpen(){
   checkForFirstOpen();
   if(ind.orderCount>=1 && ind.orderCount<=MAXLIMIT){//如果池子里有开单，且正在开单的数量<MAXLIMIT
      if(ind.firstFlag == "buy"){//首单是buy单的hedeing
         if(ind.prevFlag=="buy" && Bid<=ind.firstOpenPrice-SL*Point){ //上一单是buy，当前bid小于设置的SL,hedeing
            
            open(OP_SELL,Bid, 0, 0,Red);
            ind.prevFlag = "sell";
         }
         if(ind.prevFlag == "sell" && Ask>=ind.firstOpenPrice){
            open(OP_BUY,Ask,0,0,Blue);
            ind.prevFlag = "buy";
         }
      }
      if(ind.firstFlag == "sell"){

         if((ind.prevFlag == "sell") && Ask>=ind.firstOpenPrice+SL*Point){
            open(OP_BUY,Ask,0,0,Blue);
            ind.prevFlag = "buy";
         }
         if((ind.prevFlag == "buy") && Bid<=ind.firstOpenPrice){
            open(OP_SELL,Bid,0,0,Red);
            ind.prevFlag = "sell";
         }
      }
   }
}
void checkProfitByDay(int indexDay){
   const datetime timeStart=iTime(_Symbol,PERIOD_D1,indexDay),
                  timeEnd = TimeCurrent();
   double result=0.;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
         //filter by OrderSymbol() and OrderMagicNumber() here
         if(OrderCloseTime()<timeStart || OrderCloseTime()>=timeEnd) continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
      }
   }
   for(int j=0;j<OrdersTotal();j++){
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderOpenTime()<timeStart) continue;
         result+=OrderProfit() + OrderCommission() + OrderSwap();
   }
   ind.profitFromIdxDay = NormalizeDouble(result,2);
}
void checkForClose(){
   bool closeAll = false;
   double closePrice = 0;
   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      if(ind.orderCount>1){
         if( OrderType()==OP_BUY && (Bid>=ind.high || Bid<=ind.low)){
               Print("ticket:",OrderTicket(),",curTP:",ind.high,",curSL:",ind.low);
               closeAll = true;
               closePrice = Bid;
               break;
         }
         if(OrderType()==OP_SELL && (Ask<=ind.low || Ask>=ind.high)){
             Print("ticket:",OrderTicket(),",curTP:",ind.low,",curSL:",ind.high);
               closeAll = true;
               closePrice = Ask;
               break;
         }
      }
  }
  if(closeAll){
   int idx = 0;
   for(int j=0;j<OrdersTotal();j++){
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      //如果 仓单编号不是本系统编号，或者 仓单货币对不是当前货币对时，继续选择
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=_Symbol) continue;
      Print("orderTicket:",OrderTicket(),",pos:",j);
      closeOrder[idx] = OrderTicket();
      idx++;
      if(OrderType()==OP_BUY){
            Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue));          
            j--;

      }
      if(OrderType()==OP_SELL){
         Print("平仓结果：",OrderTicket(),"=",OrderClose(OrderTicket(),OrderLots(),Ask,0,Red));
         j--;
      }
   }
  }
}
void setCountOfEMA(){ //
   int prevBuyCount = 0;
   int prevSellCount = 0;
   string flagArr[2] = {"buy","sell"};
   for(int j=0;j<2;j++){
      for(int i=1;i<5;i++){
          double fast =  NormalizeDouble(iMA(NULL,Timeframe,EMA5,0,EMAMethod,EMAPrice,i),Digits);
          double slow =  NormalizeDouble(iMA(NULL,Timeframe,EMA6,0,EMAMethod,EMAPrice,i),Digits);
          //Print(flagArr[j],",fast=",fast,",slow=",slow);
          if(flagArr[j]=="buy"){
             if(fast>=slow){
                  prevBuyCount++;
               }
               else break;
          }
          if(flagArr[j]=="sell"){
            if(fast<=slow){
               prevSellCount++;
            }
            else break;
         }
   
      }
   }
   ind.prevEMACountOfSell = prevSellCount;
   ind.prevEMACountOfBuy = prevBuyCount;


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
     //Print("spread",SPREAD);
     if(vSpread<=SPREAD  && Period()==Timeframe){ //当前市场的点差小于设置的点差才进行计算
      RefreshRates();
      CalcInd();
      resetByOrders();
      checkProfitByDay(0);
      TrailingFirstOrder();
      checkForClose();
      //当天的 loss 值小于设置的则当天不开单了
      if(!isOpenAutoClose || ind.profitFromIdxDay>=0 || (isOpenAutoClose && ind.profitFromIdxDay<0 && MathAbs(ind.profitFromIdxDay)<MathAbs(LossPerDay))){
         checkForOpen();
      }
       Comment("profit:",ind.profitFromIdxDay
       ,"\n prevLots:",ind.prevLots,",Lots:",curLots,
       "\n orderCount:", ind.orderCount,
       "\n firstFlag:",ind.firstFlag,
       "\n prevFlag:",ind.prevFlag,
       "\n emaSignal:",ind.emaSignal,
      "\n prevEMACountOfSell:",ind.prevEMACountOfSell,
      "\n prevEMACountOfBuy:",ind.prevEMACountOfBuy
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
