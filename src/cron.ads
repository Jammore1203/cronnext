--  Cron expression parsing and schedule evaluation.
--
--  Supports the standard five fields (minute hour day-of-month month
--  day-of-week) with lists, ranges, steps, month and weekday names, and
--  the @hourly/@daily/@weekly/@monthly/@yearly shortcuts. Calendar
--  arithmetic is done on a plain Date_Time record, so the scheduler is
--  pure and independent of the system time zone.

package Cron is

   Parse_Error : exception;
   No_Match    : exception;

   type Field_Kind is (Minute, Hour, Day_Of_Month, Month, Day_Of_Week);

   type Value_Set is array (0 .. 59) of Boolean;

   type Field is record
      Values : Value_Set := (others => False);
      Star   : Boolean   := False;  --  field began with '*'
   end record;

   type Schedule is array (Field_Kind) of Field;

   subtype Month_Number  is Integer range 1 .. 12;
   subtype Day_Number    is Integer range 1 .. 31;
   subtype Hour_Number   is Integer range 0 .. 23;
   subtype Minute_Number is Integer range 0 .. 59;
   subtype Weekday       is Integer range 0 .. 6;   --  0 = Sunday

   type Date_Time is record
      Year   : Positive;
      Month  : Month_Number;
      Day    : Day_Number;
      Hour   : Hour_Number;
      Minute : Minute_Number;
   end record;

   function Parse (Expression : String) return Schedule;
   --  Raises Parse_Error with a readable message on bad input.

   function Matches (S : Schedule; T : Date_Time) return Boolean;

   function Next (S : Schedule; After : Date_Time) return Date_Time;
   --  First matching minute strictly after After. Raises No_Match if
   --  nothing matches within five years (e.g. "0 0 30 2 *").

   function Day_Of_Week (Year : Positive; Month : Month_Number;
                         Day : Day_Number) return Weekday;
   function Days_In_Month (Year : Positive; Month : Month_Number)
                           return Day_Number;

   function Image (T : Date_Time) return String;
   --  "Thu 2026-10-01 09:00"

   function Value (Text : String) return Date_Time;
   --  Parses "YYYY-MM-DD HH:MM". Raises Parse_Error.

   function Describe (S : Schedule; Kind : Field_Kind) return String;
   --  Compact human summary of one field, e.g. "Mon-Fri" or "0,15,30,45".

end Cron;
