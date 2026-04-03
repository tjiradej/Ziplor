//+------------------------------------------------------------------+
//|                                           ZiplorDashboard.mqh    |
//|                        Copyright 2026, Ziplor Project            |
//|                        https://github.com/tjiradej/Ziplor       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor Project"
#property link      "https://github.com/tjiradej/Ziplor"
#property strict

#include "ZiplorStructures.mqh"

//+------------------------------------------------------------------+
//| Dashboard Panel - On-chart information display                   |
//+------------------------------------------------------------------+
class CDashboard
  {
private:
   string            m_prefix;        // Object name prefix
   int               m_x;             // Panel X position
   int               m_y;             // Panel Y position
   int               m_width;         // Panel width
   int               m_line_height;   // Line height
   color             m_bg_color;      // Background color
   color             m_text_color;    // Default text color
   color             m_header_color;  // Header text color
   color             m_bull_color;    // Bullish color
   color             m_bear_color;    // Bearish color
   color             m_neutral_color; // Neutral color
   color             m_warning_color; // Warning color
   int               m_font_size;     // Font size
   string            m_font_name;     // Font name

   //--- Helper: create a label object on chart
   void              CreateLabel(string name, int x, int y, string text,
                                 color clr, int font_size, string font = "Consolas");
   //--- Helper: create a rectangle background
   void              CreateRectangle(string name, int x, int y, int width, int height, color clr);
   //--- Helper: update existing label text
   void              UpdateLabel(string name, string text, color clr);
   //--- Helper: format number with specified decimals
   string            FormatNumber(double value, int decimals);
   //--- Helper: get bias string
   string            BiasToString(ENUM_MARKET_BIAS bias);
   //--- Helper: get bias color
   color             BiasToColor(ENUM_MARKET_BIAS bias);
   //--- Helper: get break type string
   string            BreakToString(ENUM_STRUCTURE_BREAK brk);
   //--- Helper: get session string
   string            SessionToString(ENUM_SESSION_TYPE session);
   //--- Helper: get signal quality string
   string            QualityToString(ENUM_SIGNAL_QUALITY quality);
   //--- Helper: get recovery state string
   string            RecoveryToString(ENUM_RECOVERY_STATE state);
   //--- Helper: get streak string
   string            StreakToString(ENUM_STREAK_TYPE streak);
   //--- Helper: get timeframe string
   string            TFToString(ENUM_TIMEFRAMES tf);

public:
                     CDashboard(void);
                    ~CDashboard(void);

   //--- Initialization and destruction
   bool              Init(int x, int y, int width, string prefix = "ZPL_");
   void              Destroy(void);

   //--- Update the dashboard with current data
   void              Update(const DashboardData &data);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard(void)
   : m_prefix("ZPL_"),
     m_x(20),
     m_y(30),
     m_width(320),
     m_line_height(16),
     m_bg_color(C'20,20,30'),
     m_text_color(C'200,200,200'),
     m_header_color(C'0,180,255'),
     m_bull_color(C'0,200,100'),
     m_bear_color(C'255,80,80'),
     m_neutral_color(C'180,180,180'),
     m_warning_color(C'255,200,0'),
     m_font_size(8),
     m_font_name("Consolas")
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard(void)
  {
   Destroy();
  }

//+------------------------------------------------------------------+
//| Initialize dashboard                                             |
//+------------------------------------------------------------------+
bool CDashboard::Init(int x, int y, int width, string prefix)
  {
   m_x = x;
   m_y = y;
   m_width = width;
   m_prefix = prefix;
   return true;
  }

//+------------------------------------------------------------------+
//| Destroy all dashboard objects                                    |
//+------------------------------------------------------------------+
void CDashboard::Destroy(void)
  {
   ObjectsDeleteAll(0, m_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Create a text label on the chart                                 |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, int x, int y, string text,
                              color clr, int font_size, string font)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetString(0, obj_name, OBJPROP_FONT, font);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Create a rectangle background                                    |
//+------------------------------------------------------------------+
void CDashboard::CreateRectangle(string name, int x, int y, int width, int height, color clr)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_COLOR, C'40,40,60');
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Update an existing label                                         |
//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(string name, string text, color clr)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) >= 0)
     {
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
     }
  }

//+------------------------------------------------------------------+
//| Format number                                                    |
//+------------------------------------------------------------------+
string CDashboard::FormatNumber(double value, int decimals)
  {
   return DoubleToString(value, decimals);
  }

//+------------------------------------------------------------------+
//| Convert bias enum to string                                      |
//+------------------------------------------------------------------+
string CDashboard::BiasToString(ENUM_MARKET_BIAS bias)
  {
   switch(bias)
     {
      case BIAS_BULLISH: return "BULLISH";
      case BIAS_BEARISH: return "BEARISH";
      default:           return "NEUTRAL";
     }
  }

//+------------------------------------------------------------------+
//| Convert bias enum to color                                       |
//+------------------------------------------------------------------+
color CDashboard::BiasToColor(ENUM_MARKET_BIAS bias)
  {
   switch(bias)
     {
      case BIAS_BULLISH: return m_bull_color;
      case BIAS_BEARISH: return m_bear_color;
      default:           return m_neutral_color;
     }
  }

//+------------------------------------------------------------------+
//| Convert structure break to string                                |
//+------------------------------------------------------------------+
string CDashboard::BreakToString(ENUM_STRUCTURE_BREAK brk)
  {
   switch(brk)
     {
      case BREAK_BOS:   return "BOS";
      case BREAK_CHOCH: return "CHoCH";
      default:          return "---";
     }
  }

//+------------------------------------------------------------------+
//| Convert session to string                                        |
//+------------------------------------------------------------------+
string CDashboard::SessionToString(ENUM_SESSION_TYPE session)
  {
   switch(session)
     {
      case SESSION_ASIAN:        return "ASIAN";
      case SESSION_LONDON:       return "LONDON KZ";
      case SESSION_NY:           return "NEW YORK KZ";
      case SESSION_LONDON_CLOSE: return "LONDON CLOSE";
      case SESSION_SILVER_AM:    return "SILVER AM";
      case SESSION_SILVER_PM:    return "SILVER PM";
      default:                   return "OFF-SESSION";
     }
  }

//+------------------------------------------------------------------+
//| Convert signal quality to string                                 |
//+------------------------------------------------------------------+
string CDashboard::QualityToString(ENUM_SIGNAL_QUALITY quality)
  {
   switch(quality)
     {
      case SIGNAL_HIGH:   return "HIGH";
      case SIGNAL_MEDIUM: return "MEDIUM";
      case SIGNAL_LOW:    return "LOW";
      default:            return "NONE";
     }
  }

//+------------------------------------------------------------------+
//| Convert recovery state to string                                 |
//+------------------------------------------------------------------+
string CDashboard::RecoveryToString(ENUM_RECOVERY_STATE state)
  {
   switch(state)
     {
      case RECOVERY_WATCHING: return "WATCHING";
      case RECOVERY_ACTIVE:   return "ACTIVE";
      default:                return "OFF";
     }
  }

//+------------------------------------------------------------------+
//| Convert streak type to string                                    |
//+------------------------------------------------------------------+
string CDashboard::StreakToString(ENUM_STREAK_TYPE streak)
  {
   switch(streak)
     {
      case STREAK_WINNING: return "WINNING";
      case STREAK_LOSING:  return "LOSING";
      default:             return "---";
     }
  }

//+------------------------------------------------------------------+
//| Convert timeframe to short string                                |
//+------------------------------------------------------------------+
string CDashboard::TFToString(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "??";
     }
  }

//+------------------------------------------------------------------+
//| Update the entire dashboard                                      |
//+------------------------------------------------------------------+
void CDashboard::Update(const DashboardData &data)
  {
   int row = 0;
   int col1 = m_x + 8;            // Label column
   int col2 = m_x + 145;          // Value column
   int section_gap = 4;            // Extra pixels between sections
   int total_rows = 38;            // Estimated total rows

   //--- Background panel
   int panel_height = total_rows * m_line_height + 40;
   CreateRectangle("BG", m_x, m_y, m_width, panel_height, m_bg_color);

   //--- Title
   int cy = m_y + 6;
   CreateLabel("Title", m_x + 8, cy, "=== ZIPLOR EA v1.0 ===", m_header_color, m_font_size + 1, "Consolas Bold");
   cy += m_line_height + 4;

   //=== ACCOUNT SECTION ===
   CreateLabel("AccHdr", col1, cy, "--- ACCOUNT ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("BalLbl", col1, cy, "Balance:", m_text_color, m_font_size);
   CreateLabel("BalVal", col2, cy, FormatNumber(data.balance, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("EqLbl", col1, cy, "Equity:", m_text_color, m_font_size);
   color eq_clr = (data.equity >= data.balance) ? m_bull_color : m_bear_color;
   CreateLabel("EqVal", col2, cy, FormatNumber(data.equity, 2), eq_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("MarLbl", col1, cy, "Margin Used:", m_text_color, m_font_size);
   CreateLabel("MarVal", col2, cy, FormatNumber(data.margin_used, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("FreeLbl", col1, cy, "Free Margin:", m_text_color, m_font_size);
   CreateLabel("FreeVal", col2, cy, FormatNumber(data.free_margin, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("DPnlLbl", col1, cy, "Daily P&L:", m_text_color, m_font_size);
   color dpnl_clr = (data.daily_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("DPnlVal", col2, cy, FormatNumber(data.daily_pnl, 2), dpnl_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("WPnlLbl", col1, cy, "Weekly P&L:", m_text_color, m_font_size);
   color wpnl_clr = (data.weekly_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("WPnlVal", col2, cy, FormatNumber(data.weekly_pnl, 2), wpnl_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== POSITIONS SECTION ===
   CreateLabel("PosHdr", col1, cy, "--- POSITIONS ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("OpenLbl", col1, cy, "Open Positions:", m_text_color, m_font_size);
   CreateLabel("OpenVal", col2, cy, IntegerToString(data.open_positions), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("LotsLbl", col1, cy, "Total Lots:", m_text_color, m_font_size);
   CreateLabel("LotsVal", col2, cy, FormatNumber(data.total_lots, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("FltLbl", col1, cy, "Floating P&L:", m_text_color, m_font_size);
   color flt_clr = (data.floating_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("FltVal", col2, cy, FormatNumber(data.floating_pnl, 2), flt_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== MARKET STRUCTURE SECTION ===
   CreateLabel("MsHdr", col1, cy, "--- MARKET STRUCTURE ---", m_header_color, m_font_size);
   cy += m_line_height;

   //--- HTF
   string htf_str = TFToString(data.htf_structure.timeframe) + ":";
   CreateLabel("HtfLbl", col1, cy, htf_str, m_text_color, m_font_size);
   string htf_val = BiasToString(data.htf_structure.bias) + " " + BreakToString(data.htf_structure.last_break);
   CreateLabel("HtfVal", col2, cy, htf_val, BiasToColor(data.htf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- MTF
   string mtf_str = TFToString(data.mtf_structure.timeframe) + ":";
   CreateLabel("MtfLbl", col1, cy, mtf_str, m_text_color, m_font_size);
   string mtf_val = BiasToString(data.mtf_structure.bias) + " " + BreakToString(data.mtf_structure.last_break);
   CreateLabel("MtfVal", col2, cy, mtf_val, BiasToColor(data.mtf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- LTF
   string ltf_str = TFToString(data.ltf_structure.timeframe) + ":";
   CreateLabel("LtfLbl", col1, cy, ltf_str, m_text_color, m_font_size);
   string ltf_val = BiasToString(data.ltf_structure.bias) + " " + BreakToString(data.ltf_structure.last_break);
   CreateLabel("LtfVal", col2, cy, ltf_val, BiasToColor(data.ltf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- Execution TF
   string exec_str = TFToString(data.exec_structure.timeframe) + ":";
   CreateLabel("ExecLbl", col1, cy, exec_str, m_text_color, m_font_size);
   string exec_val = BiasToString(data.exec_structure.bias) + " " + BreakToString(data.exec_structure.last_break);
   CreateLabel("ExecVal", col2, cy, exec_val, BiasToColor(data.exec_structure.bias), m_font_size);
   cy += m_line_height + section_gap;

   //=== SESSION SECTION ===
   CreateLabel("SesHdr", col1, cy, "--- SESSION ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("SesLbl", col1, cy, "Current:", m_text_color, m_font_size);
   color ses_clr = (data.current_session == SESSION_LONDON || data.current_session == SESSION_NY) ? m_bull_color : m_neutral_color;
   CreateLabel("SesVal", col2, cy, SessionToString(data.current_session), ses_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== SIGNAL SECTION ===
   CreateLabel("SigHdr", col1, cy, "--- SIGNAL ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("SigDirLbl", col1, cy, "Direction:", m_text_color, m_font_size);
   CreateLabel("SigDirVal", col2, cy, BiasToString(data.current_signal.direction),
               BiasToColor(data.current_signal.direction), m_font_size);
   cy += m_line_height;
   CreateLabel("SigQLbl", col1, cy, "Quality:", m_text_color, m_font_size);
   color q_clr = (data.current_signal.quality == SIGNAL_HIGH) ? m_bull_color :
                 (data.current_signal.quality == SIGNAL_MEDIUM) ? m_warning_color : m_neutral_color;
   CreateLabel("SigQVal", col2, cy, QualityToString(data.current_signal.quality) +
               " (" + IntegerToString(data.current_signal.confluence_count) + " conf)", q_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("SigRRLbl", col1, cy, "Risk:Reward:", m_text_color, m_font_size);
   CreateLabel("SigRRVal", col2, cy, "1:" + FormatNumber(data.current_signal.risk_reward, 1),
               m_text_color, m_font_size);
   cy += m_line_height + section_gap;

   //=== ANTI-MARTINGALE SECTION ===
   CreateLabel("AmHdr", col1, cy, "--- ANTI-MARTINGALE ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("AmStrkLbl", col1, cy, "Streak:", m_text_color, m_font_size);
   color strk_clr = (data.am_state.streak_type == STREAK_WINNING) ? m_bull_color :
                    (data.am_state.streak_type == STREAK_LOSING) ? m_bear_color : m_neutral_color;
   int streak_num = (data.am_state.streak_type == STREAK_WINNING) ? data.am_state.consecutive_wins :
                    data.am_state.consecutive_losses;
   CreateLabel("AmStrkVal", col2, cy, StreakToString(data.am_state.streak_type) + " x" +
               IntegerToString(streak_num), strk_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("AmRskLbl", col1, cy, "Current Risk:", m_text_color, m_font_size);
   CreateLabel("AmRskVal", col2, cy, FormatNumber(data.am_state.current_risk_pct, 2) + "%", m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("AmWRLbl", col1, cy, "Win/Loss:", m_text_color, m_font_size);
   CreateLabel("AmWRVal", col2, cy, IntegerToString(data.am_state.total_wins) + "/" +
               IntegerToString(data.am_state.total_losses), m_text_color, m_font_size);
   cy += m_line_height + section_gap;

   //=== RECOVERY SECTION ===
   CreateLabel("RecHdr", col1, cy, "--- RECOVERY MODE ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("RecStLbl", col1, cy, "Status:", m_text_color, m_font_size);
   color rec_clr = (data.recovery.state == RECOVERY_ACTIVE) ? m_warning_color :
                   (data.recovery.state == RECOVERY_WATCHING) ? m_bear_color : m_neutral_color;
   CreateLabel("RecStVal", col2, cy, RecoveryToString(data.recovery.state), rec_clr, m_font_size);
   cy += m_line_height;
   if(data.recovery.state != RECOVERY_OFF)
     {
      CreateLabel("RecLossLbl", col1, cy, "To Recover:", m_text_color, m_font_size);
      CreateLabel("RecLossVal", col2, cy, FormatNumber(data.recovery.loss_to_recover - data.recovery.recovered, 2),
                  m_bear_color, m_font_size);
      cy += m_line_height;
      CreateLabel("RecTrdLbl", col1, cy, "Recovery Trades:", m_text_color, m_font_size);
      CreateLabel("RecTrdVal", col2, cy, IntegerToString(data.recovery.recovery_trades) + "/" +
                  IntegerToString(data.recovery.max_recovery_trades), m_text_color, m_font_size);
      cy += m_line_height;
     }
   cy += section_gap;

   //=== STATISTICS SECTION ===
   CreateLabel("StatHdr", col1, cy, "--- STATISTICS ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("WinRLbl", col1, cy, "Win Rate:", m_text_color, m_font_size);
   color wr_clr = (data.win_rate >= 50.0) ? m_bull_color : m_bear_color;
   CreateLabel("WinRVal", col2, cy, FormatNumber(data.win_rate, 1) + "%", wr_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("AvgRRLbl", col1, cy, "Avg R:R:", m_text_color, m_font_size);
   CreateLabel("AvgRRVal", col2, cy, "1:" + FormatNumber(data.avg_rr, 1), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("TotTLbl", col1, cy, "Total Trades:", m_text_color, m_font_size);
   CreateLabel("TotTVal", col2, cy, IntegerToString(data.total_trades), m_text_color, m_font_size);
   cy += m_line_height + 6;

   //--- Resize background to actual content
   panel_height = cy - m_y + 6;
   CreateRectangle("BG", m_x, m_y, m_width, panel_height, m_bg_color);

   ChartRedraw(0);
  }
