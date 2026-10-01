with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Cron; use Cron;

procedure Test_Cron is
   Failures : Natural := 0;

   procedure Check (Label : String; OK : Boolean) is
   begin
      if OK then
         Put_Line ("  PASS  " & Label);
      else
         Put_Line ("  FAIL  " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   function Next_Image (Expr, From : String) return String is
     (Image (Next (Parse (Expr), Value (From))));

   function Rejects (Expr : String) return Boolean is
   begin
      declare
         S : constant Schedule := Parse (Expr) with Unreferenced;
      begin
         return False;
      end;
   exception
      when Parse_Error => return True;
   end Rejects;

begin
   --  Calendar arithmetic
   Check ("day of week 2000-01-01 is Saturday", Day_Of_Week (2000, 1, 1) = 6);
   Check ("day of week 2026-10-01 is Thursday", Day_Of_Week (2026, 10, 1) = 4);
   Check ("leap year 2024", Days_In_Month (2024, 2) = 29);
   Check ("no leap year 1900", Days_In_Month (1900, 2) = 28);
   Check ("leap year 2000", Days_In_Month (2000, 2) = 29);

   --  Scheduling
   Check ("every minute rolls the hour",
          Next_Image ("* * * * *", "2026-10-01 09:59") = "Thu 2026-10-01 10:00");
   Check ("year rollover",
          Next_Image ("@yearly", "2026-12-31 23:59") = "Fri 2027-01-01 00:00");
   Check ("strictly after the start time",
          Next_Image ("30 9 * * *", "2026-10-01 09:30") = "Fri 2026-10-02 09:30");
   Check ("weekdays skip the weekend",
          Next_Image ("0 9 * * MON-FRI", "2026-10-02 10:00")
            = "Mon 2026-10-05 09:00");
   Check ("leap day finds the next leap year",
          Next_Image ("0 0 29 2 *", "2026-03-01 00:00") = "Tue 2028-02-29 00:00");
   Check ("31st skips short months",
          Next_Image ("0 0 31 * *", "2026-04-01 00:00") = "Sun 2026-05-31 00:00");
   Check ("day-of-month OR day-of-week when both set",
          Next_Image ("0 12 13 * FRI", "2026-01-10 00:00")
            = "Tue 2026-01-13 12:00");
   Check ("7 means Sunday",
          Next_Image ("0 0 * * 7", "2026-10-01 00:00") = "Sun 2026-10-04 00:00");
   Check ("steps over a range",
          Describe (Parse ("10-30/10 * * * *"), Minute) = "10,20,30");
   Check ("ranges are compressed",
          Describe (Parse ("* * * JAN-MAR,dec *"), Month) = "Jan-Mar,Dec");

   declare
      Raised : Boolean := False;
   begin
      begin
         Put_Line (Next_Image ("0 0 30 2 *", "2026-01-01 00:00"));
      exception
         when No_Match => Raised := True;
      end;
      Check ("impossible date raises No_Match", Raised);
   end;

   --  Validation
   Check ("rejects minute 60", Rejects ("60 * * * *"));
   Check ("rejects too few fields", Rejects ("* * *"));
   Check ("rejects backwards range", Rejects ("* 5-1 * * *"));
   Check ("rejects zero step", Rejects ("*/0 * * * *"));
   Check ("rejects unknown name", Rejects ("* * * * FUNDAY"));
   Check ("rejects unknown shortcut", Rejects ("@fortnightly"));

   New_Line;
   if Failures > 0 then
      Put_Line (Failures'Image & " test(s) FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   else
      Put_Line ("All cron tests passed.");
   end if;
end Test_Cron;
