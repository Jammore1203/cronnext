with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Strings;

package body Cron is

   Lowest  : constant array (Field_Kind) of Natural := (0, 0, 1, 1, 0);
   Highest : constant array (Field_Kind) of Natural := (59, 23, 31, 12, 7);

   Field_Name : constant array (Field_Kind) of access constant String :=
     (Minute       => new String'("minute"),
      Hour         => new String'("hour"),
      Day_Of_Month => new String'("day-of-month"),
      Month        => new String'("month"),
      Day_Of_Week  => new String'("day-of-week"));

   Month_Names : constant String := "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";
   Day_Names   : constant String := "SUNMONTUEWEDTHUFRISAT";

   ---------------------------------------------------------------------
   --  Calendar helpers
   ---------------------------------------------------------------------

   function Is_Leap (Year : Positive) return Boolean is
     (Year mod 4 = 0 and then (Year mod 100 /= 0 or else Year mod 400 = 0));

   function Days_In_Month (Year : Positive; Month : Month_Number)
                           return Day_Number is
   begin
      case Month is
         when 2 => return (if Is_Leap (Year) then 29 else 28);
         when 4 | 6 | 9 | 11 => return 30;
         when others => return 31;
      end case;
   end Days_In_Month;

   --  Sakamoto's method
   function Day_Of_Week (Year : Positive; Month : Month_Number;
                         Day : Day_Number) return Weekday is
      T : constant array (Month_Number) of Natural :=
        (0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4);
      Y : constant Natural := (if Month < 3 then Year - 1 else Year);
   begin
      return (Y + Y / 4 - Y / 100 + Y / 400 + T (Month) + Day) mod 7;
   end Day_Of_Week;

   function Next_Month (T : Date_Time) return Date_Time is
   begin
      if T.Month = 12 then
         return (T.Year + 1, 1, 1, 0, 0);
      else
         return (T.Year, T.Month + 1, 1, 0, 0);
      end if;
   end Next_Month;

   function Next_Day (T : Date_Time) return Date_Time is
   begin
      if T.Day = Days_In_Month (T.Year, T.Month) then
         return Next_Month (T);
      else
         return (T.Year, T.Month, T.Day + 1, 0, 0);
      end if;
   end Next_Day;

   function Next_Hour (T : Date_Time) return Date_Time is
   begin
      if T.Hour = 23 then
         return Next_Day (T);
      else
         return (T.Year, T.Month, T.Day, T.Hour + 1, 0);
      end if;
   end Next_Hour;

   function Next_Minute (T : Date_Time) return Date_Time is
   begin
      if T.Minute = 59 then
         return Next_Hour (T);
      else
         return (T.Year, T.Month, T.Day, T.Hour, T.Minute + 1);
      end if;
   end Next_Minute;

   ---------------------------------------------------------------------
   --  Parsing
   ---------------------------------------------------------------------

   function Fail (Kind : Field_Kind; Text, Why : String) return Natural is
   begin
      raise Parse_Error with Field_Name (Kind).all & " field """ & Text
        & """: " & Why;
      return 0;
   end Fail;

   function To_Number (Kind : Field_Kind; Text : String) return Natural is
      Up : constant String := To_Upper (Text);
   begin
      if Text'Length = 0 then
         return Fail (Kind, Text, "missing value");
      end if;

      if Up'Length = 3 and then Kind in Month | Day_Of_Week then
         declare
            Names : constant String :=
              (if Kind = Month then Month_Names else Day_Names);
            Idx   : constant Natural := Index (Names, Up);
         begin
            if Idx > 0 and then (Idx - Names'First) mod 3 = 0 then
               return (Idx - Names'First) / 3 + Lowest (Kind);
            end if;
         end;
      end if;

      for C of Text loop
         if not Is_Digit (C) then
            return Fail (Kind, Text, "not a number or name");
         end if;
      end loop;

      if Text'Length > 4 then
         return Fail (Kind, Text, "out of range");
      end if;

      declare
         N : constant Natural := Natural'Value (Text);
      begin
         if N < Lowest (Kind) or else N > Highest (Kind) then
            return Fail (Kind, Text, "must be" & Lowest (Kind)'Image
                         & " to" & Highest (Kind)'Image);
         end if;
         return N;
      end;
   end To_Number;

   procedure Parse_Item (Kind : Field_Kind; Item : String; F : in out Field)
   is
      Slash : constant Natural := Index (Item, "/");
      Base  : constant String :=
        (if Slash > 0 then Item (Item'First .. Slash - 1) else Item);
      Step  : Natural := 1;
      Lo    : Natural := Lowest (Kind);
      Hi    : Natural := Highest (Kind);
   begin
      if Slash > 0 then
         declare
            Step_Text : constant String := Item (Slash + 1 .. Item'Last);
         begin
            if Step_Text'Length = 0
              or else (for some C of Step_Text => not Is_Digit (C))
              or else Step_Text'Length > 2
            then
               Step := Fail (Kind, Item, "bad step");
            end if;
            Step := Natural'Value (Step_Text);
            if Step = 0 then
               Step := Fail (Kind, Item, "step must be positive");
            end if;
         end;
      end if;

      if Base = "*" then
         F.Star := True;
         if Kind = Day_Of_Week then
            Hi := 6;
         end if;
      else
         declare
            Dash : constant Natural := Index (Base, "-");
         begin
            if Dash > 0 then
               Lo := To_Number (Kind, Base (Base'First .. Dash - 1));
               Hi := To_Number (Kind, Base (Dash + 1 .. Base'Last));
               if Lo > Hi then
                  Lo := Fail (Kind, Item, "range runs backwards");
               end if;
            else
               Lo := To_Number (Kind, Base);
               Hi := (if Slash > 0 then Highest (Kind) else Lo);
            end if;
         end;
      end if;

      declare
         V : Natural := Lo;
      begin
         while V <= Hi loop
            --  7 is an alias for Sunday
            F.Values (if Kind = Day_Of_Week and V = 7 then 0 else V) := True;
            V := V + Step;
         end loop;
      end;
   end Parse_Item;

   function Parse_Field (Kind : Field_Kind; Text : String) return Field is
      F     : Field;
      Start : Positive := Text'First;
      Comma : Natural;
   begin
      loop
         Comma := Index (Text (Start .. Text'Last), ",");
         if Comma = 0 then
            Parse_Item (Kind, Text (Start .. Text'Last), F);
            exit;
         end if;
         Parse_Item (Kind, Text (Start .. Comma - 1), F);
         Start := Comma + 1;
      end loop;
      return F;
   end Parse_Field;

   function Expand_Macro (Expression : String) return String is
      E : constant String := To_Lower (Trim (Expression, Ada.Strings.Both));
   begin
      if E = "@yearly" or else E = "@annually" then
         return "0 0 1 1 *";
      elsif E = "@monthly" then
         return "0 0 1 * *";
      elsif E = "@weekly" then
         return "0 0 * * 0";
      elsif E = "@daily" or else E = "@midnight" then
         return "0 0 * * *";
      elsif E = "@hourly" then
         return "0 * * * *";
      elsif E'Length > 0 and then E (E'First) = '@' then
         raise Parse_Error with "unknown shortcut " & E;
      else
         return Expression;
      end if;
   end Expand_Macro;

   function Parse (Expression : String) return Schedule is
      Text   : constant String := Expand_Macro (Expression);
      Result : Schedule;
      Kind   : Field_Kind := Minute;
      Count  : Natural := 0;
      I      : Positive := Text'First;
      Start  : Positive;
   begin
      while I <= Text'Last loop
         if Text (I) = ' ' or else Text (I) = ASCII.HT then
            I := I + 1;
         else
            Start := I;
            while I <= Text'Last
              and then Text (I) /= ' ' and then Text (I) /= ASCII.HT
            loop
               I := I + 1;
            end loop;
            Count := Count + 1;
            if Count > 5 then
               raise Parse_Error with "too many fields (expected 5)";
            end if;
            Result (Kind) := Parse_Field (Kind, Text (Start .. I - 1));
            if Kind /= Field_Kind'Last then
               Kind := Field_Kind'Succ (Kind);
            end if;
         end if;
      end loop;

      if Count /= 5 then
         raise Parse_Error with "expected 5 fields, got" & Count'Image;
      end if;
      return Result;
   end Parse;

   ---------------------------------------------------------------------
   --  Evaluation
   ---------------------------------------------------------------------

   function Day_Matches (S : Schedule; T : Date_Time) return Boolean is
      DOM : constant Boolean := S (Day_Of_Month).Values (T.Day);
      DOW : constant Boolean :=
        S (Day_Of_Week).Values (Day_Of_Week (T.Year, T.Month, T.Day));
   begin
      --  Classic cron rule: when both day fields are restricted, a day
      --  matching either one is enough.
      if S (Day_Of_Month).Star or else S (Day_Of_Week).Star then
         return DOM and DOW;
      else
         return DOM or DOW;
      end if;
   end Day_Matches;

   function Matches (S : Schedule; T : Date_Time) return Boolean is
     (S (Month).Values (T.Month)
      and then Day_Matches (S, T)
      and then S (Hour).Values (T.Hour)
      and then S (Minute).Values (T.Minute));

   function Next (S : Schedule; After : Date_Time) return Date_Time is
      T : Date_Time := Next_Minute (After);
   begin
      --  Skip whole months, days and hours at a time, so finding even a
      --  yearly match takes a few hundred steps, not half a million.
      while T.Year <= After.Year + 5 loop
         if not S (Month).Values (T.Month) then
            T := Next_Month (T);
         elsif not Day_Matches (S, T) then
            T := Next_Day (T);
         elsif not S (Hour).Values (T.Hour) then
            T := Next_Hour (T);
         elsif not S (Minute).Values (T.Minute) then
            T := Next_Minute (T);
         else
            return T;
         end if;
      end loop;
      raise No_Match with "no matching time in the next five years";
   end Next;

   ---------------------------------------------------------------------
   --  Formatting
   ---------------------------------------------------------------------

   function Pad (N : Natural; Width : Positive := 2) return String is
      Img : constant String := Trim (N'Image, Ada.Strings.Left);
   begin
      return (1 .. Width - Img'Length => '0') & Img;
   end Pad;

   function Image (T : Date_Time) return String is
      D : constant Weekday := Day_Of_Week (T.Year, T.Month, T.Day);
      Name : constant String := Day_Names (D * 3 + 1 .. D * 3 + 3);
   begin
      return Name (Name'First) & To_Lower (Name (Name'First + 1 .. Name'Last))
        & " "
        & Pad (T.Year, 4) & "-" & Pad (T.Month) & "-" & Pad (T.Day) & " "
        & Pad (T.Hour) & ":" & Pad (T.Minute);
   end Image;

   function Value (Text : String) return Date_Time is
      S : constant String := Trim (Text, Ada.Strings.Both);
   begin
      if S'Length /= 16 or else S (S'First + 4) /= '-'
        or else S (S'First + 7) /= '-' or else S (S'First + 13) /= ':'
      then
         raise Parse_Error with "expected YYYY-MM-DD HH:MM, got """
           & Text & """";
      end if;
      declare
         F  : constant Positive := S'First;
         Y  : constant Positive := Positive'Value (S (F .. F + 3));
         Mo : constant Month_Number := Month_Number'Value (S (F + 5 .. F + 6));
         D  : constant Day_Number := Day_Number'Value (S (F + 8 .. F + 9));
      begin
         if D > Days_In_Month (Y, Mo) then
            raise Parse_Error with "no such date " & S (F .. F + 9);
         end if;
         return (Y, Mo, D,
                 Hour_Number'Value (S (F + 11 .. F + 12)),
                 Minute_Number'Value (S (F + 14 .. F + 15)));
      end;
   exception
      when Constraint_Error =>
         raise Parse_Error with "invalid date/time """ & Text & """";
   end Value;

   function Label (Kind : Field_Kind; V : Natural) return String is
   begin
      case Kind is
         when Month =>
            return Month_Names ((V - 1) * 3 + 1)
              & To_Lower (Month_Names ((V - 1) * 3 + 2 .. (V - 1) * 3 + 3));
         when Day_Of_Week =>
            return Day_Names (V * 3 + 1)
              & To_Lower (Day_Names (V * 3 + 2 .. V * 3 + 3));
         when others =>
            return Trim (V'Image, Ada.Strings.Left);
      end case;
   end Label;

   function Describe (S : Schedule; Kind : Field_Kind) return String is
      Lo     : constant Natural := Lowest (Kind);
      Hi     : constant Natural := (if Kind = Day_Of_Week then 6
                                    else Highest (Kind));
      F      : constant Field := S (Kind);
      Result : Unbounded_String;
      V      : Natural := Lo;
      Run_End : Natural;
   begin
      if (for all I in Lo .. Hi => F.Values (I)) then
         case Kind is
            when Minute       => return "every minute";
            when Hour         => return "every hour";
            when Day_Of_Month => return "any day";
            when Month        => return "every month";
            when Day_Of_Week  => return "any weekday";
         end case;
      end if;

      while V <= Hi loop
         if F.Values (V) then
            Run_End := V;
            while Run_End < Hi and then F.Values (Run_End + 1) loop
               Run_End := Run_End + 1;
            end loop;
            if Length (Result) > 0 then
               Append (Result, ",");
            end if;
            Append (Result, Label (Kind, V));
            if Run_End >= V + 2 then
               Append (Result, "-" & Label (Kind, Run_End));
            elsif Run_End = V + 1 then
               Append (Result, "," & Label (Kind, Run_End));
            end if;
            V := Run_End + 1;
         else
            V := V + 1;
         end if;
      end loop;
      return To_String (Result);
   end Describe;

end Cron;
