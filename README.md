EA ADVANCED MONEY MANAGER - MT5
====================================
## Ceci n'est pas un conseil en investissement ou une source sur de rentabilité, il faut toujours tester ce script en compte démo en fonction de vos attentes et méthode de trading, l'auteur de ce script ne pourras pas être tenu responsable des risque pris avec celui ci.
DESCRIPTION
-----------
Cette outils est un Expert Advisor  pour MetaTrader 5 qui automatise la gestion des risques et des positions avec des fonctionnalités avancées de money management.

FONCTIONNALITÉS PRINCIPALES
---------------------------

🛡️ STOP LOSS INITIAL
- Activation/Désactivation du Stop Loss initial
- Double mode de calcul : 
  * Perte maximale en Dollars (prioritaire)
  * Perte maximale en Pourcentage du capital
- Validation automatique des paramètres

⚖️ BREAK-EVEN (SEUIL DE RENTABILITÉ)
- 3 modes de fonctionnement :
  * Mode Ratio Risque/Rendement (ex: 1.3x le risque initial)
  * Mode Dollars (profit fixe en $)
  * Mode Pourcentage (% du capital)
- Priorisation intelligente des paramètres

📈 TRAILING STOP AMÉLIORÉ
- 3 modes avancés :
  * Mode Dollars : Déclenchement par profit en $
  * Mode ATR : Adapté à la volatilité du marché
  * Mode Points : Distance fixe en points
- Système de cache ATR pour optimiser les performances

💰 CLÔTURE PARTIELLE
- 3 modes de déclenchement :
  * Profit en Dollars
  * Ratio Risque/Rendement
  * Pourcentage du capital
- Pourcentage personnalisable de la position à clôturer

PARAMÈTRES DE CONFIGURATION
---------------------------

=== STOP LOSS INITIAL ===

EnableInitialSL : Activer le Stop Loss initial

MaxLossDollar : Perte maximale en $ (prioritaire si > 0)

MaxLossPercent : Perte maximale en % du capital


=== BREAK-EVEN ===

EnableBreakEven : Activer le Break-Even

BreakEvenMode : Mode de calcul (RR/Dollars/Pourcentage)

BreakEvenDollar : Profit en $ pour activation

BreakEvenRR : Ratio Risque/Rendement

BreakEvenPercent : Profit en % du capital



=== TRAILING STOP AMÉLIORÉ ===

EnableTrailing : Activer le Trailing Stop

TrailingMode : Mode (Dollars/ATR/Points)

TrailStartDollar : Profit en $ pour démarrer

TrailStepDollar : Distance en $ pour le trailing

TrailStartPercent : Profit en % capital

TrailStepPercent : Distance en % capital

TrailPoints : Distance en points


TrailATRMultiplier : Multiplicateur ATR

TrailATRPeriod : Période ATR (14 = standard)



=== CLÔTURE PARTIELLE ===


EnablePartialClose : Activer la clôture partielle

PartialCloseMode : Mode de déclenchement

PartialCloseDollar : Profit en $ pour clôture

PartialCloseRR : Ratio pour clôture

PartialClosePercent : Profit en % du capital



ClosePercent : % de la position à clôturer

=== PARAMÈTRES GÉNÉRAUX ===

MagicNumber : Identifiant unique (0 = toutes les positions)

ShowAlerts : Afficher les alertes popup

DetailedLogs : Logs détaillés dans l'onglet Experts





INSTALLATION
------------
1. Copiez le fichier .ex5 dans MQL5/Experts/
2. Redémarrez MetaTrader 5
3. Attachez l'EA sur le graphique souhaité
4. Configurez les paramètres selon votre stratégie
5. Activez le trading automatique

FONCTIONNALITÉS TECHNIQUES
--------------------------
- Traitement de toutes les positions ou filtrage par Magic Number
- Cache ATR pour éviter les calculs répétitifs
- Validation des paramètres de trading
- Gestion des erreurs complète
- Redimensionnement dynamique des tableaux

NOTES IMPORTANTES
-----------------
- Magic Number = 0 : L'EA traite TOUTES les positions
- Les paramètres en Dollars sont prioritaires
- Testez toujours en compte démo avant utilisation réelle
- Ajustez les paramètres selon votre tolérance au risque

VERSION
-------
v2.10 - Version améliorée avec trailing stop optimisé et gestion ATR

Développé pour MetaTrader 5 - Gestion Hardcore de Risques

# Discord : theglitch_is
