--  cronnext - explain a cron expression and list its next run times.
--
--    cronnext EXPRESSION [-n COUNT] [--from "YYYY-MM-DD HH:MM"]

with Ada.Calendar;            use Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Exceptions;          use Ada.Exceptions;
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Cron;                    use Cron;

procedure Cronnext is

   Expression : Unbounded_String;
   Count      : Positive := 5;
   From       : Date_Time;
   Have_From  : Boolean := False;
   I          : Positive := 1;

   procedure Usage is
   begin
      Put_Line ("usage: cronnext EXPRESSION [-n COUNT] "
                & "[--from ""YYYY-MM-DD HH:MM""]");
      Put_Line ("  e.g. cronnext ""*/15 9-17 * * MON-FRI"" -n 10");
   end Usage;

   procedure Die (Message : String) is
   begin
      Put_Line (Standard_Error, "cronnext: " & Message);
      Set_Exit_Status (2);
   end Die;

   function Now return Date_Time is
      T : constant Time := Clock;
      Y : Year_Number; Mo : Ada.Calendar.Month_Number;
      D : Ada.Calendar.Day_Number;
      H : Ada.Calendar.Formatting.Hour_Number;
      Mi : Ada.Calendar.Formatting.Minute_Number;
      S : Ada.Calendar.Formatting.Second_Number;
      SS : Ada.Calendar.Formatting.Second_Duration;
   begin
      Ada.Calendar.Formatting.Split
        (T, Y, Mo, D, H, Mi, S, SS,
         Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (T));
      return (Y, Mo, D, H, Mi);
   end Now;

begin
   while I <= Argument_Count loop
      declare
         A : constant String := Argument (I);
      begin
         if A = "-h" or else A = "--help" then
            Usage;
            return;
         elsif A = "-n" and then I < Argument_Count then
            I := I + 1;
            Count := Positive'Value (Argument (I));
         elsif A = "--from" and then I < Argument_Count then
            I := I + 1;
            From := Value (Argument (I));
            Have_From := True;
         elsif Length (Expression) = 0 then
            Expression := To_Unbounded_String (A);
         else
            Die ("unexpected argument """ & A & """ (quote the expression)");
            return;
         end if;
      end;
      I := I + 1;
   end loop;

   if Length (Expression) = 0 then
      Usage;
      Set_Exit_Status (2);
      return;
   end if;

   if not Have_From then
      From := Now;
   end if;

   declare
      S : constant Schedule := Parse (To_String (Expression));
      T : Date_Time := From;
   begin
      Put_Line ("minute    " & Describe (S, Minute));
      Put_Line ("hour      " & Describe (S, Hour));
      Put_Line ("day       " & Describe (S, Day_Of_Month));
      Put_Line ("month     " & Describe (S, Month));
      Put_Line ("weekday   " & Describe (S, Day_Of_Week));
      New_Line;
      Put_Line ("next" & Count'Image
                & (if Count = 1 then " run" else " runs") & " after " & Image (From) & ":");
      for N in 1 .. Count loop
         T := Next (S, T);
         Put_Line ("  " & Image (T));
      end loop;
   end;

exception
   when E : Parse_Error | No_Match =>
      Die (Exception_Message (E));
   when Constraint_Error =>
      Die ("invalid number in arguments");
end Cronnext;
