unit UIIcons;
{$mode objfpc}{$H+}
interface
uses Graphics;
function ButtonIcon(Kind: Integer): TBitmap;
implementation
uses Types;
procedure Stroke(C: TCanvas; Color: TColor; Width: Integer);
begin C.Pen.Color:=Color; C.Pen.Width:=Width; C.Pen.Style:=psSolid; end;
function ButtonIcon(Kind: Integer): TBitmap;
var C: TCanvas; Blue,Green,Orange,Red,Ink: TColor;
begin
  Result:=TBitmap.Create; Result.SetSize(24,24); C:=Result.Canvas;
  C.Brush.Color:=clFuchsia; C.FillRect(0,0,24,24);
  Result.TransparentColor:=clFuchsia; Result.Transparent:=True;
  Blue:=RGBToColor(32,102,170); Green:=RGBToColor(27,145,98);
  Orange:=RGBToColor(194,113,24); Red:=RGBToColor(181,61,62);
  Ink:=RGBToColor(57,76,96);
  case Kind of
    0..2: begin // Host: server cabinet
      Stroke(C,Blue,2); C.Brush.Color:=clWhite; C.RoundRect(3,3,20,21,3,3);
      Stroke(C,Ink,1); C.MoveTo(5,10); C.LineTo(18,10);
      C.MoveTo(5,15); C.LineTo(18,15);
      C.Brush.Color:=Blue; C.Ellipse(6,6,8,8); C.Ellipse(6,12,8,14);
      C.Brush.Color:=clWhite; C.Pen.Color:=clFuchsia; C.Ellipse(11,11,24,24);
      if Kind=0 then begin
        Stroke(C,Green,2); C.MoveTo(17,14); C.LineTo(17,21);
        C.MoveTo(13,18); C.LineTo(21,18);
      end else if Kind=1 then begin
        Stroke(C,Orange,3); C.MoveTo(13,21); C.LineTo(21,13);
      end else begin
        Stroke(C,Red,2); C.MoveTo(13,18); C.LineTo(21,18);
      end;
    end;
    3: begin // Refresh
      Stroke(C,Blue,2); C.Brush.Style:=bsClear; C.Arc(4,4,21,21,18,6,6,15);
      C.Brush.Style:=bsSolid; C.Brush.Color:=Blue; C.Pen.Color:=Blue;
      C.Polygon([Point(19,3),Point(22,9),Point(15,9)]);
    end;
    4: begin // Start
      C.Brush.Color:=Green; C.Pen.Color:=Green;
      C.Polygon([Point(6,3),Point(21,12),Point(6,21)]);
    end;
    5: begin // Graceful shutdown
      Stroke(C,Orange,2); C.Brush.Style:=bsClear;
      C.Arc(4,4,21,21,18,8,7,8);
      C.MoveTo(12,2); C.LineTo(12,13); C.Brush.Style:=bsSolid;
    end;
    6: begin // Restart
      Stroke(C,Orange,2); C.Brush.Style:=bsClear; C.Arc(4,4,21,21,18,6,6,15);
      C.Brush.Style:=bsSolid; C.Brush.Color:=Orange; C.Pen.Color:=Orange;
      C.Polygon([Point(19,3),Point(22,9),Point(15,9)]);
    end;
    7: begin // Force stop
      C.Brush.Color:=Red; C.Pen.Color:=Red; C.RoundRect(4,4,21,21,3,3);
    end;
    8: begin // Console monitor
      Stroke(C,Blue,2); C.Brush.Color:=RGBToColor(226,242,251);
      C.RoundRect(2,3,22,18,2,2);
      C.MoveTo(12,18); C.LineTo(12,22); C.MoveTo(7,22); C.LineTo(17,22);
    end;
    9: begin // SSH key
      Stroke(C,Blue,2); C.Brush.Style:=bsClear; C.Ellipse(2,3,13,14);
      C.Brush.Style:=bsSolid; C.MoveTo(11,12); C.LineTo(21,22);
      C.MoveTo(17,18); C.LineTo(19,16);
    end;
    10: begin // VM settings
      Stroke(C,Blue,2); C.Brush.Style:=bsClear; C.Ellipse(5,5,20,20);
      C.Ellipse(9,9,16,16); C.MoveTo(12,1); C.LineTo(12,5);
      C.MoveTo(12,20); C.LineTo(12,24); C.MoveTo(1,12); C.LineTo(5,12);
      C.MoveTo(20,12); C.LineTo(24,12); C.Brush.Style:=bsSolid;
    end;
    11: begin // Clone
      Stroke(C,Blue,2); C.Brush.Color:=clWhite;
      C.Rectangle(3,3,16,16); C.Rectangle(8,8,21,21);
      Stroke(C,Green,2); C.MoveTo(13,14); C.LineTo(13,19);
      C.MoveTo(11,17); C.LineTo(16,17);
    end;
  end;
end;
end.
