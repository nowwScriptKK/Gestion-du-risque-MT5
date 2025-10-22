#property copyright "Money Manager EA"
#property version   "2.10"
#property description "EA avancé pour gestion money management"
#property description "SL, BE, Trailing Stop, Clôture partielle"
#property description "VERSION AMELIOREE - Trailing Stop optimisé"

// Définition des énumérations
enum ENUM_BE_MODE
{
   BE_MODE_RR,                                  // Mode Ratio Risque/Rendement (ex: 1.3 = 1.3x le risque initial)
   BE_MODE_DOLLAR,                              // Mode Dollars (profit fixe en $)
   BE_MODE_PERCENT                              // Mode Pourcentage (% du capital)
};

enum ENUM_TRAILING_MODE
{
   TRAIL_MODE_DOLLAR,                           // Mode Dollars (déclenchement par profit $)
   TRAIL_MODE_ATR,                              // Mode ATR (adapté à la volatilité)
   TRAIL_MODE_POINTS                            // Mode Points (fixe en points)
};

enum ENUM_PARTIAL_MODE
{
   PARTIAL_MODE_DOLLAR,                         // Mode Dollars
   PARTIAL_MODE_RR,                             // Mode Ratio
   PARTIAL_MODE_PERCENT                         // Mode Pourcentage capital
};

// Paramètres de Stop Loss Initial
input group "=== STOP LOSS INITIAL ==="
input bool     EnableInitialSL = true;          // Activer le Stop Loss initial
input double   MaxLossDollar = 50.0;           // [DOLLARS] Perte max en $ (prioritaire si > 0)
input double   MaxLossPercent = 0.6;           // [POURCENT] Perte max en % du capital (utilisé si Dollars = 0)

// Paramètres de Break-Even
input group "=== BREAK-EVEN ==="
input bool     EnableBreakEven = true;          // Activer le Break-Even (SL au prix d'ouverture)
input ENUM_BE_MODE BreakEvenMode = BE_MODE_RR; // Mode Break-Even

input double   BreakEvenDollar = 50.0;         // [DOLLARS] Profit en $ pour activer BE (prioritaire)
input double   BreakEvenRR = 1.3;              // [RATIO] Ratio Risque/Rendement (1.3 = 1.3x le risque)
input double   BreakEvenPercent = 1.0;         // [POURCENT] Profit en % du capital pour BE

// Paramètres de Trailing Stop AMELIORES
input group "=== TRAILING STOP AMELIORE ==="
input bool     EnableTrailing = false;          // Activer le Trailing Stop
input ENUM_TRAILING_MODE TrailingMode = TRAIL_MODE_DOLLAR; // Mode Trailing

// --- MODE DOLLARS ---
input double   TrailStartDollar = 50.0;        // [DOLLARS] Profit en $ pour démarrer trailing (prioritaire)
input double   TrailStepDollar = 60.0;         // [DOLLARS] Distance en $ entre prix et SL une fois trailing activé
input double   TrailStartPercent = 1.5;        // [POURCENT] Profit en % capital (utilisé si Dollars = 0)
input double   TrailStepPercent = 1.0;         // [POURCENT] Distance en % capital (utilisé si Step Dollars = 0)

// --- MODE POINTS ---
input int      TrailPoints = 50;               // [POINTS] Distance en points entre prix et SL

// --- MODE ATR ---
input double   TrailATRMultiplier = 2.0;       // [MULTIPLICATEUR] Multiplicateur ATR (ex: 2.0 = 2x ATR)
input int      TrailATRPeriod = 14;            // [PERIODE] Période ATR (14 = standard)

// Paramètres de Clôture Partielle
input group "=== CLOTURE PARTIELLE ==="
input bool     EnablePartialClose = true;      // Activer clôture partielle
input ENUM_PARTIAL_MODE PartialCloseMode = PARTIAL_MODE_DOLLAR; // Mode clôture partielle

input double   PartialCloseDollar = 200.0;      // [DOLLARS] Profit en $ pour clôture partielle
input double   PartialCloseRR = 1.0;           // [RATIO] Ratio pour clôture partielle
input double   PartialClosePercent = 1.0;      // [POURCENT] Profit en % capital
input double   ClosePercent = 50.0;            // [POURCENT] % de la position à clôturer

// Paramètres généraux
input group "=== PARAMETRES GENERAUX ==="
input int      MagicNumber = 0;                // Magic Number (0 = traiter TOUTES les positions)
input bool     ShowAlerts = true;              // Afficher les alertes popup
input bool     DetailedLogs = true;            // Logs détaillés dans l'onglet Experts

// Variables globales
double equity;
bool trailingActivated[];
bool breakEvenActivated[];
bool partialCloseActivated[];
datetime lastATRCalcTime = 0;
double cachedATR = 0;
string cachedATRSymbol = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== EA Advanced Money Manager V2.10 Démarré ===");
    Print("=== CONFIGURATION ===");
    Print("SL Initial: ", EnableInitialSL, " | Perte max: ", MaxLossDollar, "$, ", MaxLossPercent, "%");
    Print("Break-Even: ", EnableBreakEven, " | Mode: ", EnumToString(BreakEvenMode));
    Print("Trailing: ", EnableTrailing, " | Mode: ", EnumToString(TrailingMode));
    Print("Clôture Partielle: ", EnablePartialClose, " | Mode: ", EnumToString(PartialCloseMode));
    Print("Magic Number: ", MagicNumber, " (0 = traiter TOUTES les positions)");
    
    // Validation des paramètres
    if(!ValidateParameters())
    {
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialiser les tableaux avec une taille suffisante
    ArrayResize(trailingActivated, 1000);
    ArrayResize(breakEvenActivated, 1000);
    ArrayResize(partialCloseActivated, 1000);
    
    // Initialiser les tableaux
    ArrayInitialize(trailingActivated, false);
    ArrayInitialize(breakEvenActivated, false);
    ArrayInitialize(partialCloseActivated, false);
    
    Print("=== INITIALISATION TERMINEE ===");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Validation des paramètres                                        |
//+------------------------------------------------------------------+
bool ValidateParameters()
{
    bool valid = true;
    
    if(EnableInitialSL && MaxLossDollar <= 0 && MaxLossPercent <= 0)
    {
        Print("⚠️ ATTENTION: SL initial activé mais aucune valeur de perte définie!");
        valid = false;
    }
    
    if(EnableBreakEven)
    {
        if(BreakEvenMode == BE_MODE_DOLLAR && BreakEvenDollar <= 0 && BreakEvenRR <= 0 && BreakEvenPercent <= 0)
        {
            Print("⚠️ ATTENTION: Break-Even activé en mode Dollar mais aucun seuil défini!");
            valid = false;
        }
        else if(BreakEvenMode == BE_MODE_RR && BreakEvenRR <= 0 && BreakEvenDollar <= 0 && BreakEvenPercent <= 0)
        {
            Print("⚠️ ATTENTION: Break-Even activé en mode RR mais aucun ratio défini!");
            valid = false;
        }
        else if(BreakEvenMode == BE_MODE_PERCENT && BreakEvenPercent <= 0 && BreakEvenDollar <= 0 && BreakEvenRR <= 0)
        {
            Print("⚠️ ATTENTION: Break-Even activé en mode Pourcentage mais aucun % défini!");
            valid = false;
        }
    }
    
    if(EnableTrailing)
    {
        if(TrailingMode == TRAIL_MODE_DOLLAR && TrailStartDollar <= 0 && TrailStartPercent <= 0)
        {
            Print("⚠️ ATTENTION: Trailing activé en mode Dollar mais aucun seuil de départ défini!");
            valid = false;
        }
        if(TrailingMode == TRAIL_MODE_POINTS && TrailPoints <= 0)
        {
            Print("⚠️ ATTENTION: Trailing activé en mode Points mais TrailPoints = 0!");
            valid = false;
        }
        if(TrailingMode == TRAIL_MODE_ATR && TrailATRMultiplier <= 0)
        {
            Print("⚠️ ATTENTION: Trailing activé en mode ATR mais multiplicateur = 0!");
            valid = false;
        }
    }
    
    if(EnablePartialClose && ClosePercent <= 0)
    {
        Print("⚠️ ATTENTION: Clôture partielle activée mais ClosePercent = 0!");
        valid = false;
    }
    
    return valid;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== EA Advanced Money Manager arrêté - Raison: ", reason, " ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastProcessTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Traiter les positions toutes les 500ms (environ)
    if(currentTime > lastProcessTime || (currentTime == lastProcessTime && GetTickCount() % 500 == 0))
    {
        equity = AccountInfoDouble(ACCOUNT_EQUITY);
        ProcessPositions();
        lastProcessTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Traiter toutes les positions                                     |
//+------------------------------------------------------------------+
void ProcessPositions()
{
    int totalPositions = PositionsTotal();
    
    if(DetailedLogs && totalPositions > 0)
        Print("🔍 Nombre de positions trouvées: ", totalPositions);
    else if(totalPositions == 0)
    {
        if(DetailedLogs) Print("Aucune position ouverte");
        return;
    }
    
    // Redimensionner les tableaux si nécessaire
    if(totalPositions > ArraySize(trailingActivated))
    {
        int newSize = totalPositions + 100;
        ArrayResize(trailingActivated, newSize);
        ArrayResize(breakEvenActivated, newSize);
        ArrayResize(partialCloseActivated, newSize);
        
        // Initialiser les nouveaux éléments
        for(int i = ArraySize(trailingActivated) - 100; i < newSize; i++)
        {
            trailingActivated[i] = false;
            breakEvenActivated[i] = false;
            partialCloseActivated[i] = false;
        }
    }
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            // NE PAS vérifier le magic number - traiter TOUTES les positions
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double currentSL = PositionGetDouble(POSITION_SL);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            long magic = PositionGetInteger(POSITION_MAGIC);
            
            if(DetailedLogs)
            {
                Print("📊 Traitement " + symbol + " Ticket:" + IntegerToString(ticket) + " Magic:" + IntegerToString(magic) + 
                      " Type:" + EnumToString(type) + " SL:" + DoubleToString(currentSL, 5) + " Profit:" + DoubleToString(currentProfit, 2));
            }
            
            // Gestion du SL initial
            if(EnableInitialSL && currentSL == 0)
            {
                if(DetailedLogs) Print("🎯 Tentative de définition du SL initial pour " + symbol);
                double newSL = CalculateInitialSL(symbol, volume, openPrice, type);
                if(newSL > 0) 
                {
                    if(ModifyPositionSL(ticket, symbol, newSL, magic))
                    {
                        Print("✅ SL initial défini pour " + symbol + " Ticket: " + IntegerToString(ticket) + 
                              " SL: " + DoubleToString(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                    }
                    else
                    {
                        Print("❌ Échec de la définition du SL initial pour " + symbol);
                    }
                }
                else
                {
                    Print("❌ Calcul du SL initial échoué pour " + symbol);
                }
            }
            
            // Gestion du Break-Even
            if(EnableBreakEven && currentSL != 0 && !breakEvenActivated[i])
            {
                if(DetailedLogs) Print("🔍 Vérification Break-Even pour " + symbol);
                if(CheckBreakEven(ticket, symbol, volume, openPrice, currentSL, type, currentProfit, i, magic))
                {
                    breakEvenActivated[i] = true;
                    Print("✅ Break-Even activé pour " + symbol);
                }
            }
            
            // Gestion du Trailing Stop AMELIOREE
            if(EnableTrailing && currentSL != 0)
            {
                if(DetailedLogs) Print("🔍 Vérification Trailing Stop pour " + symbol);
                CheckTrailingStop(ticket, symbol, volume, openPrice, currentSL, type, currentProfit, i, magic);
            }
            
            // Gestion de la clôture partielle
            if(EnablePartialClose && !partialCloseActivated[i])
            {
                if(DetailedLogs) Print("🔍 Vérification Clôture Partielle pour " + symbol);
                if(CheckPartialClose(ticket, symbol, volume, openPrice, currentSL, type, currentProfit, i, magic))
                {
                    partialCloseActivated[i] = true;
                    Print("✅ Clôture partielle effectuée pour " + symbol);
                }
            }
        }
        else
        {
            Print("❌ Impossible de sélectionner la position avec l'index " + IntegerToString(i));
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer le Stop Loss initial                                    |
//+------------------------------------------------------------------+
double CalculateInitialSL(string symbol, double volume, double openPrice, ENUM_POSITION_TYPE type)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    if(tickSize == 0 || tickValue == 0 || point == 0) 
    {
        Print("❌ Erreur: Impossible de récupérer les informations du symbole " + symbol);
        return 0;
    }
    
    // PRIORISATION: $ puis % (ligne du haut prioritaire)
    double maxLoss = MaxLossDollar;
    
    // Si la valeur en $ est 0, utiliser la valeur en %
    if(MaxLossDollar <= 0)
    {
        maxLoss = (MaxLossPercent / 100.0) * AccountInfoDouble(ACCOUNT_BALANCE);
    }
    
    // Vérifier si une perte maximale est définie
    if(maxLoss <= 0)
    {
        Print("❌ Aucune perte maximale définie pour le SL initial");
        return 0;
    }
    
    // Calculer la distance en points pour la perte maximale
    double lossInPoints = (maxLoss / (volume * tickValue)) * (tickSize / point);
    
    double newSL = 0;
    double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    if(type == POSITION_TYPE_BUY)
    {
        newSL = openPrice - lossInPoints * point;
        // Vérifier que le SL est valide
        if(newSL >= currentPrice)
        {
            Print("❌ SL calculé invalide pour BUY. SL: " + DoubleToString(newSL, digits) + " Prix courant: " + DoubleToString(currentPrice, digits));
            return 0;
        }
    }
    else if(type == POSITION_TYPE_SELL)
    {
        newSL = openPrice + lossInPoints * point;
        // Vérifier que le SL est valide
        if(newSL <= currentPrice)
        {
            Print("❌ SL calculé invalide pour SELL. SL: " + DoubleToString(newSL, digits) + " Prix courant: " + DoubleToString(currentPrice, digits));
            return 0;
        }
    }
    
    return NormalizeDouble(newSL, digits);
}

//+------------------------------------------------------------------+
//| Vérifier et appliquer le Break-Even                              |
//+------------------------------------------------------------------+
bool CheckBreakEven(ulong ticket, string symbol, double volume, double openPrice, 
                   double currentSL, ENUM_POSITION_TYPE type, double currentProfit, int index, long magic)
{
    double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    double initialRisk = MathAbs(openPrice - currentSL);
    bool shouldMoveToBE = false;
    
    // PRIORISATION: $ puis RR puis % (ligne du haut prioritaire)
    switch(BreakEvenMode)
    {
        case BE_MODE_DOLLAR:
            if(BreakEvenDollar > 0)
            {
                shouldMoveToBE = (currentProfit >= BreakEvenDollar);
            }
            else if(BreakEvenRR > 0)
            {
                shouldMoveToBE = ((type == POSITION_TYPE_BUY && currentPrice >= openPrice + initialRisk * BreakEvenRR) ||
                               (type == POSITION_TYPE_SELL && currentPrice <= openPrice - initialRisk * BreakEvenRR));
            }
            else if(BreakEvenPercent > 0)
            {
                shouldMoveToBE = (currentProfit >= (BreakEvenPercent / 100.0) * equity);
            }
            break;
            
        case BE_MODE_RR:
            if(BreakEvenRR > 0)
            {
                shouldMoveToBE = ((type == POSITION_TYPE_BUY && currentPrice >= openPrice + initialRisk * BreakEvenRR) ||
                               (type == POSITION_TYPE_SELL && currentPrice <= openPrice - initialRisk * BreakEvenRR));
            }
            else if(BreakEvenDollar > 0)
            {
                shouldMoveToBE = (currentProfit >= BreakEvenDollar);
            }
            else if(BreakEvenPercent > 0)
            {
                shouldMoveToBE = (currentProfit >= (BreakEvenPercent / 100.0) * equity);
            }
            break;
            
        case BE_MODE_PERCENT:
            if(BreakEvenPercent > 0)
            {
                shouldMoveToBE = (currentProfit >= (BreakEvenPercent / 100.0) * equity);
            }
            else if(BreakEvenDollar > 0)
            {
                shouldMoveToBE = (currentProfit >= BreakEvenDollar);
            }
            else if(BreakEvenRR > 0)
            {
                shouldMoveToBE = ((type == POSITION_TYPE_BUY && currentPrice >= openPrice + initialRisk * BreakEvenRR) ||
                               (type == POSITION_TYPE_SELL && currentPrice <= openPrice - initialRisk * BreakEvenRR));
            }
            break;
    }
    
    if(shouldMoveToBE)
    {
        // Vérifier si le SL n'est pas déjà au BE ou mieux
        bool needToMoveSL = false;
        
        if(type == POSITION_TYPE_BUY && currentSL < openPrice)
            needToMoveSL = true;
        else if(type == POSITION_TYPE_SELL && currentSL > openPrice)
            needToMoveSL = true;
        
        if(needToMoveSL)
        {
            double newSL = NormalizeDouble(openPrice, digits);
            if(ModifyPositionSL(ticket, symbol, newSL, magic))
            {
                string message = "✅ Break-Even activé " + symbol + " Ticket:" + IntegerToString(ticket) + 
                               " SL:" + DoubleToString(newSL, digits) + " Profit:" + DoubleToString(currentProfit, 2);
                Print(message);
                if(ShowAlerts) Alert(message);
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier et appliquer le Trailing Stop AMELIORE                 |
//+------------------------------------------------------------------+
void CheckTrailingStop(ulong ticket, string symbol, double volume, double openPrice, 
                      double currentSL, ENUM_POSITION_TYPE type, double currentProfit, int index, long magic)
{
    double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    double newSL = currentSL;
    bool shouldTrail = false;
    double trailStep = 0;
    
    // Vérifier si le trailing doit démarrer
    switch(TrailingMode)
    {
        case TRAIL_MODE_DOLLAR:
            // PRIORISATION: $ puis % (ligne du haut prioritaire)
            if(TrailStartDollar > 0)
            {
                shouldTrail = (currentProfit >= TrailStartDollar);
                if(shouldTrail)
                {
                    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                    trailStep = (TrailStepDollar > 0 ? TrailStepDollar : (TrailStepPercent / 100.0) * equity) / (volume * tickValue) * (tickSize / point) * point;
                }
            }
            else if(TrailStartPercent > 0)
            {
                shouldTrail = (currentProfit >= (TrailStartPercent / 100.0) * equity);
                if(shouldTrail)
                {
                    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                    trailStep = (TrailStepDollar > 0 ? TrailStepDollar : (TrailStepPercent / 100.0) * equity) / (volume * tickValue) * (tickSize / point) * point;
                }
            }
            break;
            
        case TRAIL_MODE_POINTS:
            {
                double profitInPoints = (type == POSITION_TYPE_BUY) ? (currentPrice - openPrice) / point : (openPrice - currentPrice) / point;
                shouldTrail = (profitInPoints >= TrailPoints);
                trailStep = TrailPoints * point;
            }
            break;
            
        case TRAIL_MODE_ATR:
            {
                double atr = GetCurrentATR(symbol);
                double profitInPoints = (type == POSITION_TYPE_BUY) ? (currentPrice - openPrice) / point : (openPrice - currentPrice) / point;
                shouldTrail = (profitInPoints >= atr / point);
                trailStep = atr * TrailATRMultiplier;
            }
            break;
    }
    
    if(shouldTrail)
    {
        if(!trailingActivated[index])
        {
            trailingActivated[index] = true;
            Print("🎯 Trailing Stop activé pour " + symbol + " Ticket: " + IntegerToString(ticket) + " Profit: " + DoubleToString(currentProfit, 2));
        }
        
        // Calculer le nouveau SL
        if(type == POSITION_TYPE_BUY)
        {
            newSL = currentPrice - trailStep;
            // CORRECTION IMPORTANTE: Vérifier que le nouveau SL est meilleur que l'ancien ET meilleur que le prix d'ouverture
            if(newSL > currentSL && newSL > openPrice) 
            {
                if(ModifyPositionSL(ticket, symbol, newSL, magic))
                {
                    Print("✅ Trailing BUY " + symbol + 
                          " Ancien SL: " + DoubleToString(currentSL, digits) + 
                          " Nouveau SL: " + DoubleToString(newSL, digits) +
                          " Prix: " + DoubleToString(currentPrice, digits));
                }
            }
            else if(DetailedLogs)
            {
                Print("🔍 Trailing BUY non déclenché - NewSL:" + DoubleToString(newSL, digits) + " CurrentSL:" + DoubleToString(currentSL, digits) + " OpenPrice:" + DoubleToString(openPrice, digits));
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            newSL = currentPrice + trailStep;
            // CORRECTION IMPORTANTE: Vérifier que le nouveau SL est meilleur que l'ancien ET meilleur que le prix d'ouverture
            if(newSL < currentSL && newSL < openPrice) 
            {
                if(ModifyPositionSL(ticket, symbol, newSL, magic))
                {
                    Print("✅ Trailing SELL " + symbol + 
                          " Ancien SL: " + DoubleToString(currentSL, digits) + 
                          " Nouveau SL: " + DoubleToString(newSL, digits) +
                          " Prix: " + DoubleToString(currentPrice, digits));
                }
            }
            else if(DetailedLogs)
            {
                Print("🔍 Trailing SELL non déclenché - NewSL:" + DoubleToString(newSL, digits) + " CurrentSL:" + DoubleToString(currentSL, digits) + " OpenPrice:" + DoubleToString(openPrice, digits));
            }
        }
    }
    else if(DetailedLogs && trailingActivated[index])
    {
        string thresholdText = "";
        if(TrailingMode == TRAIL_MODE_DOLLAR) thresholdText = DoubleToString(TrailStartDollar, 2);
        else if(TrailingMode == TRAIL_MODE_POINTS) thresholdText = IntegerToString(TrailPoints);
        else thresholdText = "ATR";
        
        Print("🔍 Trailing déjà activé mais conditions non remplies - Profit:" + DoubleToString(currentProfit, 2) + 
              " Seuil requis:" + thresholdText);
    }
}

//+------------------------------------------------------------------+
//| Obtenir la valeur ATR courante avec cache                        |
//+------------------------------------------------------------------+
double GetCurrentATR(string symbol)
{
    // Recalculer l'ATR seulement si le symbole a changé ou après un certain temps
    if(symbol != cachedATRSymbol || TimeCurrent() - lastATRCalcTime > PeriodSeconds(PERIOD_CURRENT))
    {
        cachedATR = iATR(symbol, PERIOD_CURRENT, TrailATRPeriod);
        cachedATRSymbol = symbol;
        lastATRCalcTime = TimeCurrent();
        
        if(DetailedLogs)
            Print("📊 ATR recalculé pour " + symbol + ": " + DoubleToString(cachedATR, 5));
    }
    return cachedATR;
}

//+------------------------------------------------------------------+
//| Vérifier et appliquer la clôture partielle                       |
//+------------------------------------------------------------------+
bool CheckPartialClose(ulong ticket, string symbol, double volume, double openPrice, 
                      double currentSL, ENUM_POSITION_TYPE type, double currentProfit, int index, long magic)
{
    bool shouldClosePartial = false;
    
    // PRIORISATION: $ puis RR puis % (ligne du haut prioritaire)
    switch(PartialCloseMode)
    {
        case PARTIAL_MODE_DOLLAR:
            if(PartialCloseDollar > 0)
            {
                shouldClosePartial = (currentProfit >= PartialCloseDollar);
            }
            else if(PartialCloseRR > 0)
            {
                double initialRisk = MathAbs(openPrice - currentSL);
                double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
                double profitInPoints = MathAbs(currentPrice - openPrice);
                shouldClosePartial = (profitInPoints >= initialRisk * PartialCloseRR);
            }
            else if(PartialClosePercent > 0)
            {
                shouldClosePartial = (currentProfit >= (PartialClosePercent / 100.0) * equity);
            }
            break;
            
        case PARTIAL_MODE_RR:
            if(PartialCloseRR > 0)
            {
                double initialRisk = MathAbs(openPrice - currentSL);
                double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
                double profitInPoints = MathAbs(currentPrice - openPrice);
                shouldClosePartial = (profitInPoints >= initialRisk * PartialCloseRR);
            }
            else if(PartialCloseDollar > 0)
            {
                shouldClosePartial = (currentProfit >= PartialCloseDollar);
            }
            else if(PartialClosePercent > 0)
            {
                shouldClosePartial = (currentProfit >= (PartialClosePercent / 100.0) * equity);
            }
            break;
            
        case PARTIAL_MODE_PERCENT:
            if(PartialClosePercent > 0)
            {
                shouldClosePartial = (currentProfit >= (PartialClosePercent / 100.0) * equity);
            }
            else if(PartialCloseDollar > 0)
            {
                shouldClosePartial = (currentProfit >= PartialCloseDollar);
            }
            else if(PartialCloseRR > 0)
            {
                double initialRisk = MathAbs(openPrice - currentSL);
                double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
                double profitInPoints = MathAbs(currentPrice - openPrice);
                shouldClosePartial = (profitInPoints >= initialRisk * PartialCloseRR);
            }
            break;
    }
    
    if(shouldClosePartial)
    {
        double closeVolume = NormalizeDouble(volume * (ClosePercent / 100.0), 2);
        if(closeVolume < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
        {
            closeVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        }
        
        if(closeVolume >= volume)
        {
            closeVolume = volume; // Éviter de clôturer plus que le volume disponible
        }
        
        if(ClosePartialPosition(ticket, symbol, closeVolume, magic))
        {
            string message = "✅ Clôture partielle " + symbol + " Ticket:" + IntegerToString(ticket) + 
                           " Volume:" + DoubleToString(closeVolume, 2) + " Profit:" + DoubleToString(currentProfit, 2);
            Print(message);
            if(ShowAlerts) Alert(message);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Modifier le Stop Loss d'une position AMELIORE                   |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, string symbol, double newSL, long magic)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    // Vérifier les stops levels du broker
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    double minDistance = stopLevel > 0 ? stopLevel : point * 10; // Distance minimale
    
    // Vérifier la distance minimale
    if(posType == POSITION_TYPE_BUY && MathAbs(currentPrice - newSL) < minDistance)
    {
        Print("❌ SL trop proche du prix pour BUY - Distance: " + DoubleToString(MathAbs(currentPrice - newSL), 5) + " Min: " + DoubleToString(minDistance, 5));
        return false;
    }
    if(posType == POSITION_TYPE_SELL && MathAbs(newSL - currentPrice) < minDistance)
    {
        Print("❌ SL trop proche du prix pour SELL - Distance: " + DoubleToString(MathAbs(newSL - currentPrice), 5) + " Min: " + DoubleToString(minDistance, 5));
        return false;
    }
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = symbol;
    request.sl = newSL;
    request.tp = PositionGetDouble(POSITION_TP);
    request.magic = magic; // Conserver le magic number original
    
    // Normalisation des prix
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    request.sl = NormalizeDouble(request.sl, digits);
    if(request.tp > 0) 
        request.tp = NormalizeDouble(request.tp, digits);
    
    // Envoi de l'ordre
    bool sent = OrderSend(request, result);
    if(sent)
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            return true;
        }
        else
        {
            Print("❌ Erreur OrderSend pour modification SL. Code: " + IntegerToString(result.retcode) + " Ticket: " + IntegerToString(ticket));
            return false;
        }
    }
    else
    {
        Print("❌ Échec OrderSend pour modification SL. Ticket: " + IntegerToString(ticket));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Clôturer partiellement une position                              |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, string symbol, double volume, long magic)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = symbol;
    request.volume = NormalizeDouble(volume, 2);
    request.deviation = 10;
    request.magic = magic; // Conserver le magic number original
    
    if(type == POSITION_TYPE_BUY)
    {
        request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
        request.type = ORDER_TYPE_SELL;
    }
    else
    {
        request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        request.type = ORDER_TYPE_BUY;
    }
    
    request.type_filling = ORDER_FILLING_FOK;
    
    bool sent = OrderSend(request, result);
    if(sent)
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            return true;
        }
        else
        {
            Print("❌ Erreur clôture partielle. Code: " + IntegerToString(result.retcode) + " Ticket: " + IntegerToString(ticket));
        }
    }
    else
    {
        Print("❌ Échec OrderSend pour clôture partielle. Ticket: " + IntegerToString(ticket));
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Fonction pour gérer les trades                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Réinitialiser les flags lorsque des trades sont modifiés
    ArrayInitialize(trailingActivated, false);
    ArrayInitialize(breakEvenActivated, false);
    ArrayInitialize(partialCloseActivated, false);
    
    if(DetailedLogs)
        Print("🔄 Événement OnTrade - réinitialisation des flags");
}
