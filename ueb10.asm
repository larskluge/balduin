; Spiel: Balduin der Ball

.386

; Bildschirmspeicher
c_videoseg    EQU 0A000h
c_videobreite EQU 320
c_videohoehe  EQU 200
c_dac_adrreg  EQU 3C8h
c_statusreg   EQU 3DAh

; Bildparameter
c_maxbildbreite EQU 16
c_maxbildhoehe  EQU 1600
c_speed         EQU 2     ; Bewegungsgeschwindigkeit - Angabe in Pixel

; Spielfeldparameter
c_spielfelddateiid   EQU 'DLAB' ; Achtung ID rückwärts!! Für DWORD-Vergleich
c_maxspielfeldbreite EQU 128
c_maxspielfeldhoehe  EQU 128

; Balduin
c_balduin_screenpos_y EQU 16
c_maxsprunghoehe      EQU 52
c_sprunghoehestep     EQU 8
c_maxlaufweite        EQU 64

; Animation
c_animation_bildwechsel EQU 8 ; wechsel alle x Frames (x=2^n)
c_animation_spritemin   EQU 7
c_animation_spritemax   EQU 10

; Sprites
c_sprite_himmel     EQU 0
c_sprite_grasboden  EQU 1
c_sprite_erdboden   EQU 2
c_sprite_mauer      EQU 3
c_sprite_wasser     EQU 4
c_sprite_wassertief EQU 5
c_sprite_stachel    EQU 6
c_sprite_balduin    EQU 11

; Spriteparameter
c_spritebreite EQU 16
c_spritehoehe  EQU 16

; Bitmap Format
c_bmp_id             EQU 0
c_bmp_dateilaenge    EQU 2
c_bmp_reserviert     EQU 6
c_bmp_pixeldaten     EQU 10
c_bmp_formatgroesse  EQU 14
c_bmp_bildbreite     EQU 18
c_bmp_bildhoehe      EQU 22
c_bmp_ebenen         EQU 26
c_bmp_bitspropixel   EQU 28
c_bmp_kompression    EQU 30
c_bmp_datengroesse   EQU 34
c_bmp_xaufloesung    EQU 38
c_bmp_yaufloesung    EQU 42
c_bmp_genutztefarben EQU 46
c_bmp_wichtigefarben EQU 50

; BALD Format
c_bald_id               EQU 0
c_bald_breite           EQU 4
c_bald_hoehe            EQU 6
c_bald_reserviert       EQU 8
c_bald_spritepositionen EQU 16 ; ab hier beginnen die Spielfeldinformationen der Spritepositionen





;Codesegment
code SEGMENT USE16
ASSUME CS:code,DS:data

start:

; Segmente DS+ES auf data initialisieren..
MOV AX,SEG data
MOV DS,AX ; DS auf Datensegment setzen
MOV ES,AX ; ES auf Datensegment setzen

; Tastertur-Handle installieren..
CALL intinstallieren ;(void)

; Grafikmodus aktivieren..
CALL grafikein ; (void)

neustart:

; Initialisiert das Spiel
CALL initspiel

; Palette der Sprites-BMP aktivieren..
LEA SI,palette
CALL aktivierepalette ; (DS:SI=Palette)

; Spiel mit der Game-Loop starten..
CALL startgame ; (DS=Datensegment): CY=Balduin tod
JC neustart ; Balduin gestorben, Level neustarten
; prüfen ob Benutzerabbruch oder Spiel gewonnen
CMP ndiamanten,0
JNE diamantenvorhanden
  ; keine Diamanten mehr vorhanden
  ; nächstes Spielfeld laden
  LEA DI,spielfelddatei
  CALL naechstesspielfeld
  JNC naechstesspielfeldvorhanden
    ; nächstes Spielfeld nicht vorhanden -> Spiel gewonnen
    MOV CX,1 ; Status: Spiel gewonnen!
    JMP spielgewonnen
  naechstesspielfeldvorhanden:
  JMP neustart
diamantenvorhanden:
XOR CX,CX ; Spielabbruch
spielgewonnen:

;zurueck in den Textmodus..
CALL grafikaus ; (void)

; Tastertur-Handle deinstallieren..
CALL intwiederherstellen ; (void)

; ggf. Spiel gewonnen-Meldung
JCXZ spielabgebrochen
  LEA DX,txt_spielgewonnen
  CALL textausgabe
spielabgebrochen:

;Programm beenden
programmbeenden:
MOV AX,4C00h
INT 21h





; Initialisiert das Spiel
; Parameter:
; Ausgabe  :
initspiel PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DI
PUSH SI
PUSH BP


; Spielphysik
MOV sprunghoehe,0
MOV maxsprunghoehe,c_sprunghoehestep
MOV sprungrichtung,0
MOV laufrichtung,0

; Sprite-BMP-Datei laden..
LEA DX,spritedatei
LEA DI,bildbreite
LEA BP,palette
CALL ladebitmap ; (DS:DX=Dateiname, ES:DI=Zielpuffer fuer Bild, ES:BP=Zielpuffer fuer Palette, buffer=Zwischenspeicher)
JNC ladebitmaperfolgreich
  CALL textausgabe ; (DS:DX=Text) ; Fehlermeldung ausgeben
  JMP programmbeenden             ; anschliessend Programm beenden
ladebitmaperfolgreich:

;Spielfeld aus Datei laden..
LEA DX,spielfelddatei
LEA DI,spielfeldbreite
CALL ladespielfeld ; (DS:DX=Dateiname, ES:DI=Zielpuffer für Spielfeld)
JNC ladespielfelderfolgreich
  CALL textausgabe ; (DS:DX=Text)
  JMP programmbeenden
ladespielfelderfolgreich:

; Anzahl der Sprites ermitteln..
CALL spritesanzahlermitteln ; (DS=Datensegment)


; Balduin-Position aus Spielfeld ermitteln + Diamanten zählen..
LEA SI,spielfeld

MOV AX,spielfeldbreite
MUL spielfeldhoehe
MOV CX,AX

MOV ndiamanten,0 ; Diamanten-Zähler auf 0 setzen
XOR AX,AX ; Zähler
initspiel1:
  MOV BL,DS:[SI] ; aktuelle Sprite

  ; Suche nach Balduin
  CMP BL,c_sprite_balduin
  JNE initspiel2
    ; Balduin-Sprite gefunden
    XOR DX,DX
    DIV spielfeldbreite
    PUSH DX ; Rest sichern
    ; Balduin x Position in Pixeln setzen
    MOV BX,c_spritehoehe
    MUL BX
    MOV balduin_y,AX

    ; Balduin y Position in Pixeln setzen
    POP AX ; Div-Rest wiederherstellen
    MOV BX,c_spritebreite
    MUL BX
    MOV balduin_x,AX
    ; Balduin-Sprite im Spielfeld durch Himmel ersetzen..
    MOV BYTE PTR DS:[SI],c_sprite_himmel
    JMP initspiel4
  initspiel2:

  ; Suche nach Diamanten
  CMP BL,c_animation_spritemin
  JB initspiel4
    ; Diamant gefunden
    INC ndiamanten
  initspiel4:

  INC AX
  INC SI
LOOP initspiel1
initspiel3:



POP BP
POP SI
POP DI
POP DX
POP CX
POP BX
POP AX
RET
initspiel ENDP




; Startet das Spiel
; Wird erst bei drücken der ESC-Taste beendet
; Parameter: DS = Datensegment
; Ausgabe:   CY = Balduin tod
startgame PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DI
PUSH SI
PUSH ES


; ES auf Video-Segment setzen..
MOV AX,c_videoseg
MOV ES,AX

; zu Testzwecken kann die Diamantenanzahl des Levels überschrieben werden
;MOV ndiamanten,3

; Initialisierungen..
XOR CX,CX ; Framezähler/Animationszähler
XOR DI,DI ; zeigt auf Anfang des mit DI kombinierten Segments
XOR SI,SI ; zeigt auf Anfang des mit SI kombinierten Segments

gameloop:
  ; richtet den Bildschrim zentriert auf Balduin aus
  CALL screenausrichten

	; stellt das Spielfeld im Puffer dar..
  CALL spielfelddarstellen ; (CX=Frame, DS=Datensegment)

  ; setzt Balduin in Puffer..
  CALL balduindarstellen

  ; wartet bis sich der Kathodenstrahl im vertikalen Rücklauf befindet..
  CALL wartevr ; (void)

  ; kopiert den Buffer ins Videoram..
  PUSH DS
  MOV AX,SEG buffer
  MOV DS,AX
  CALL kopierepuffer ; (DS:SI=Quellbuffer, ES:DI=Zielbuffer Videoram)
  POP DS

	; leert den Puffer für die Eingaben der Tastertur..
  CALL tastaturpufferleeren ; (void)

  ; verarbeitet die spielereingaben
  CALL spielereingabe

  ; Balduin-X-Position an Zylinderwelt anpassen
  MOV AX,spielfeldbreite_px
  CMP balduin_x,0
  JNL startgame_poskorrekt1
    ; Balduin links neben Hauptspielfeld
    ADD balduin_x,AX
    JMP startgame_poskorrekt2
  startgame_poskorrekt1:
  CMP balduin_x,AX
  JNG startgame_poskorrekt2
    ; Balduin rechts neben Hauptspielfeld
    SUB balduin_x,AX
  startgame_poskorrekt2:

  ; Lauf-Trägheit automatisch langsam zurücksetzen
  CMP laufrichtung,0
  JL startgame_laufrichtunginc
  JG startgame_laufrichtungdec
  JMP startgame4
    startgame_laufrichtunginc:
      INC laufrichtung
      JMP startgame4
    startgame_laufrichtungdec:
      DEC laufrichtung
  startgame4:

  ; Balduin-X-Position an Laufrichtung anpassen
  CMP laufrichtung,0
  JL startgame_nachlinks
  JG startgame_nachrechts
  JMP startgame3
  startgame_nachlinks:
    SUB balduin_x,c_speed
    JMP startgame3
  startgame_nachrechts:
    ADD balduin_x,c_speed
  startgame3:


  ; prüft auf Kollision mit tötenden Objekten
  MOV AX,balduin_x
  MOV BX,balduin_y
  MOV DL,1000b ; tötende Elemente
  CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
  OR DL,DL
  JNZ startgame1


  ; von Balduin berührte Diamanten werden eingesammelt
  CALL diamanteneinsammeln


  ; Spielphysik (wird erst im nächsten Schleifendurchlauf sichtbar)
  ; Änderung von Y-Werten
  CALL balduin_erdanziehung
  CALL balduin_sprung
  CALL balduin_aufprall
  ; Änderung von X-Werten
  CALL balduin_seitlicheraufprall


  ; Animationszähler erhöhen
  INC CX

  ; beenden wenn keine Diamanten mehr vorhanden
  CMP ndiamanten,0
  JE startgame2

  ; ESC-Status prüfen
  CMP BYTE PTR CS:tastenstatus+4,1 ; +4 = ESC
JNE gameloop ; bis ESC-Taste gedrückt wird oder durch andere Ereignisse aus der Schleife gesprungen wird
startgame2:
CLC ; Exitstatus: Benutzerabbruch oder alle Diamanten eingesammelt
JMP startgame_ende
startgame1:
STC ; Exitstatus: Balduin ist gestorben, Level muss neu initialisiert werden
startgame_ende:


POP ES
POP SI
POP DI
POP DX
POP CX
POP BX
POP AX
RET
startgame ENDP





; Spielphysik: Auf Balduin wirkt die Erdanziehungskraft, er fällt runter
;              solange, bis er wieder Boden unter den Füßen hat
; Parameter: -
; Ausgabe  : vertikale Positionsveränderung von Balduin
balduin_erdanziehung PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI


; bei Sprung wirkt Schwerkraft nicht
CMP sprungrichtung,1
JE balduin_erdanziehung_ende

; Balduin-Position holen
MOV AX,balduin_x
MOV BX,balduin_y

; am Bildschirmrand nicht weiter fallen
MOV DX,spielfeldhoehe_px
SUB DX,c_spritehoehe
CMP BX,DX
JAE balduin_erdanziehung_ende

; weiter fallen, wenn vertikal im Sprite-Raster!
TEST BX,c_spritehoehe-1
JNZ balduin_erdanziehung1

; auf Kollision mit blockierenden Elementen prüfen
ADD BX,c_spritehoehe ; Element unter Balduin checken
MOV DL,0100b ; blockierende Elemente
CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
OR DL,DL
JZ balduin_erdanziehung2
  JMP balduin_erdanziehung_ende
balduin_erdanziehung2:

balduin_erdanziehung1:
ADD balduin_y,c_speed
SUB sprunghoehe,c_speed
ADD maxsprunghoehe,c_speed
MOV sprungrichtung,-1 ; Status: Balduin fällt

balduin_erdanziehung_ende:


POP SI
POP DX
POP CX
POP BX
POP AX
RET
balduin_erdanziehung ENDP





; läßt Balduin springen
balduin_sprung PROC
PUSH AX
PUSH BX
PUSH DX


; Sprungrichtung muss nach oben gehen
CMP sprungrichtung,1
JNE balduin_sprung_ende

; oberer Bildschirmrand erreicht?
CMP balduin_y,0
JLE balduin_sprung4
; blockierendes Objekt oben?
MOV AX,balduin_x
MOV BX,balduin_y
TEST BX,c_spritehoehe-1
JNZ balduin_sprung1
; Balduin vertikal im Sprite-Raster
  SUB BX,c_spritehoehe
  MOV DL,0100b ; blockierende Elemente
  CALL pruefekollision
  OR DL,DL
  JZ balduin_sprung1
    balduin_sprung4:
    ; maxsprunghoehe begrenzen
    MOV sprungrichtung,-1 ; Balduin fallen lassen
    MOV maxsprunghoehe,c_sprunghoehestep
    JMP balduin_sprung_ende
balduin_sprung1:

; pro Sprung immer etwas höher springen, bis c_maxsprunghoehe
MOV AX,maxsprunghoehe
CMP sprunghoehe,AX
JNE balduin_sprung2
CMP CS:tastenstatus,1 ; 0 = Taste oben
JNE balduin_sprung2
CMP maxsprunghoehe,c_maxsprunghoehe
JNL balduin_sprung2
  ; maxsprunghoehe < maxsprunghoehe aus eigener Kraft von Balduin
  ADD maxsprunghoehe,c_sprunghoehestep
  CMP maxsprunghoehe,c_maxsprunghoehe
  JB balduin_sprung2
    MOV maxsprunghoehe,c_maxsprunghoehe
balduin_sprung2:


MOV AX,maxsprunghoehe
CMP sprunghoehe,AX
JNL balduin_sprung3
  SUB balduin_y,c_speed ; Balduin-Position weiter nach oben setzen
  ADD sprunghoehe,c_speed ; Sprunghoehe erhöhen
  JMP balduin_sprung_ende
balduin_sprung3:
; Wendepunkt erreicht
MOV sprungrichtung,-1
MOV maxsprunghoehe,c_sprunghoehestep

balduin_sprung_ende:


POP DX
POP BX
POP AX
RET
balduin_sprung ENDP





; prüft auf Aufprall von Balduin mit blockierenden Elementen (vertikal)
;   Aufprall -> Balduin springt wieder hoch
; Paramter: keine
balduin_aufprall PROC
PUSH AX
PUSH BX
PUSH DX


MOV AX,balduin_x
MOV BX,balduin_y

TEST BX,c_spritehoehe-1
JNZ balduin_aufprall_ende
  ; Balduin vertikal im Sprite-Raster
  ADD BX,c_spritehoehe ; Sprite unter Balduin testen
  MOV DL,0100b ; blockierende Elemente
  CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
  OR DL,DL
  JZ balduin_aufprall_ende
    NEG sprungrichtung ; Sprungrichtung umkehren
    MOV sprunghoehe,0
    ; Maximale Sprunghöhe pro Sprung um x Pixel verringern
    SUB maxsprunghoehe,2*c_sprunghoehestep ; doppelt abziehen, da beim Sprung 1x addiert wird
    CMP maxsprunghoehe,0
    JGE balduin_aufprall_ende
      MOV maxsprunghoehe,c_sprunghoehestep
      MOV sprungrichtung,0

balduin_aufprall_ende:


POP DX
POP BX
POP AX
RET
balduin_aufprall ENDP





; prüft auf Aufprall von Balduin mit blockierenden Elementen (horizontal)
;   Aufprall -> Balduin prallt zurück
; Parameter: keine
balduin_seitlicheraufprall PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX


MOV AX,balduin_x
TEST AX,c_spritebreite-1
JNZ balduin_seitlicheraufprall_ende
  ; Balduin horizontal im Sprite-Raster

  ; wenn Balduin sich nicht bewegt, kann keine seitliche Kollision ausgelöst werden
  CMP laufrichtung,0
  JZ balduin_seitlicheraufprall_ende
  ; Vorzeichen von spritebreite der Laufweite(-richtung) angleichen, damit in diese Richtung zuerst geprüft wird
  XOR CH,CH
  MOV CL,c_spritebreite
  CMP laufrichtung,0
  JG balduin_seitlicheraufprall2
    ; laufrichtung < 0
    NEG CX
  balduin_seitlicheraufprall2:
  ; 1. Seite prüfen (links oder rechts)
  MOV AX,balduin_x
  ADD AX,CX
  MOV BX,balduin_y
  MOV DL,0100b ; blockierende Elemente
  CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
  TEST DL,0101b
  JZ balduin_seitlicheraufprall_ende
  ; 2. Seite prüfen (entgegengesetzt der vorherig geprüften Seite)
  MOV AX,balduin_x
  NEG CX
  ADD AX,CX
  MOV DL,0100b ; blockierende Elemente
  CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
  TEST DL,0101b
  JZ balduin_seitlicheraufprall1
    ; Balduin befindet sich zwischen zwei blockierenden Elementen
    ; -> Laufrichtung kann nicht umgekehrt werden -> Laufrichtung wird auf 0 gesetzt
    MOV laufrichtung,0
    JMP balduin_seitlicheraufprall_ende
  balduin_seitlicheraufprall1:
  ; Balduin prallt seitlich von blockierenden Objekten ab
  NEG laufrichtung


balduin_seitlicheraufprall_ende:


POP DX
POP CX
POP BX
POP AX
RET
balduin_seitlicheraufprall ENDP





; wertet die Eingabe des Spielers aus und bewegt Balduin über das Spielfeld
; Parameter: tastenstatus
spielereingabe PROC
PUSH AX
PUSH BX
PUSH DX


; Tastatur-Eingaben auswerten (und Balduin bewegen)..
; Taste LINKS
CMP BYTE PTR CS:tastenstatus+3,1 ; +3 = links
JNE tasterechts
  MOV AX,balduin_x
  SUB AX,c_spritebreite
  TEST AX,c_spritebreite-1
  JNZ tastelinks1
    MOV BX,balduin_y
    MOV DL,0100b ; blockierende Elemente
    CALL pruefekollision
    OR DL,DL
    JNZ tasterechts
  tastelinks1:
  CMP laufrichtung,-c_maxlaufweite
  JNG tasterechts
    SUB laufrichtung,2


tasterechts:
; Taste RECHTS
CMP BYTE PTR CS:tastenstatus+1,1 ; +1 = rechts
JNE tasteoben
  MOV AX,balduin_x
  ADD AX,c_spritebreite
  TEST AX,c_spritebreite-1
  JNZ tasterechts1
    MOV DL,0100b ; blockierende Elemente
    MOV BX,balduin_y
    CALL pruefekollision
    OR DL,DL
    JNZ tasteoben
  tasterechts1:
  CMP laufrichtung,c_maxlaufweite
  JNL tasteoben
    ADD laufrichtung,2


tasteoben:
; Taste OBEN
CMP BYTE PTR CS:tastenstatus,1 ; 0 = oben
JNE spielereingabe_ende
  CMP sprungrichtung,0
  JNE spielereingabe_ende
    MOV sprungrichtung,1 ; löst Sprung von Balduin aus


spielereingabe_ende:


POP DX
POP BX
POP AX
RET
spielereingabe ENDP





; prüft, ob der Spieler mit Objekten auf dem Spielfeld kollidiert
; je nach Kollision mit Objekt wird entsprechende Aktion ausgelöst
; Parameter: AX = Balduin X-Pos
;            BX = Balduin Y-Pos
;            DL = Kollisionsinformationen: Himmel (1.Bit), Diamanten (2.Bit), blockierende Elemente (3.Bit), tötende Elemente (4.Bit)
; Ausgabe:   DL = Kollision wo: oben links (1.Bit), oben rechts (2.Bit), unten links (3.Bit), unten rechts (4.Bit)
pruefekollision PROC
; Stackrahmen initialisieren
PUSH BP
MOV BP,SP
SUB SP,10 ; 10 Bytes Platz fuer lokale Variablen reservieren

; BP-2: Balduin Pos X (pixel) umgerechnet
; BP-4: Balduin Pos Y (pixel) umgerechnet

; BP-6: 1. Objekt-Sprite X
; BP-8: 1. Objekt-Sprite Y

; BP-9: Kollisionsinformationen
; BP-10: Ergebnisausgabe

; restliche Register sichern
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI

MOV [BP-9],DL ; Kollisionsinformationen sichern
MOV BYTE PTR [BP-10],0 ; Ergebnisausgabe leer initialisieren

OR DL,DL ; Keine Kollisionsinformationen -> keine Kollisionsauswertung
JZ pruefekollision_ende

; Balduin Pos X umrechnen
CMP AX,0
JNL pruefekollision1
  ; Balduin an negativer Position
  ADD AX,spielfeldbreite_px
  JMP pruefekollision2
pruefekollision1:
CMP AX,spielfeldbreite_px
JL pruefekollision2
  ; Balduin zu weit im positiven Bereich
  SUB AX,spielfeldbreite_px
pruefekollision2:
MOV [BP-2],AX ; Balduin Pos X umgerechnet

; berechnet Balduin Pos Y
MOV [BP-4],BX ; Balduin Pos Y "umgerechnet"


MOV BX,c_spritebreite ; hierdurch wird später geteilt

; Objekt x-Wert berechnen
MOV AX,[BP-2]
XOR DX,DX
DIV BX
MOV [BP-6],AX ; Objekt x-Wert zwischenspeichern

; Objekt y-Wert berechnen
MOV AX,[BP-4]
XOR DX,DX
DIV BX
MOV [BP-8],AX ; Objekt y-Wert zwischenspeichern

; Objekt-Sprite im Spielfeld ermitteln
LEA SI,spielfeld
MUL spielfeldbreite
ADD SI,AX
ADD SI,[BP-6]


; Balduin-Sprite Kollision oben links
MOV DL,[BP-9]
CALL kollisionauswerten ; (DL=Kollisionsinfo,DS:SI=Sprite im Spielfeld): CY=Kollision
JNC keine_kollision_obenlinks
  OR BYTE PTR [BP-10],0001b ; Kollision oben links merken
keine_kollision_obenlinks:


; Balduin-Sprite Kollision oben rechts
TEST WORD PTR [BP-2],c_spritebreite-1
JZ pruefekollision3
  ; Sprite im Spielfeld ermitteln
  LEA SI,spielfeld
  MOV AX,[BP-8]
  MOV BX,[BP-6]
  MOV DX,spielfeldbreite
  DEC DX
  CMP BX,DX
  JNE pruefekollision4
    XOR BX,BX
    JMP pruefekollision5
  pruefekollision4:
    INC BX
  pruefekollision5:
  MUL spielfeldbreite
  ADD SI,AX
  ADD SI,BX

  MOV DL,[BP-9]
  CALL kollisionauswerten
  JNC pruefekollision3
    OR BYTE PTR [BP-10],0010b ; Kollision oben rechts merken
pruefekollision3:


; Balduin-Sprite Kollision unten links
TEST WORD PTR [BP-4],c_spritehoehe-1
JZ pruefekollision6
  ; Sprite im Spielfeld ermitteln
  LEA SI,spielfeld
  MOV AX,[BP-8]
  MOV BX,[BP-6]
  INC AX
  MUL spielfeldbreite
  ADD SI,AX
  ADD SI,BX

  MOV DL,[BP-9]
  CALL kollisionauswerten
  JNC pruefekollision6
    OR BYTE PTR [BP-10],0100b ; Kollision unten links merken
pruefekollision6:


; Balduin-Sprite Kollision unten rechts
TEST WORD PTR [BP-2],c_spritebreite-1
JZ pruefekollision_ende
TEST WORD PTR [BP-4],c_spritehoehe-1
JZ pruefekollision_ende
  ; Sprite im Spielfeld ermitteln
  LEA SI,spielfeld
  MOV AX,[BP-8]
  MOV BX,[BP-6]
  MOV DX,spielfeldbreite
  DEC DX
  CMP BX,DX
  JNE pruefekollision8
    XOR BX,BX
    JMP pruefekollision9
  pruefekollision8:
    INC BX
  pruefekollision9:
  INC AX
  MUL spielfeldbreite
  ADD SI,AX
  ADD SI,BX

  MOV DL,[BP-9]
  CALL kollisionauswerten
  JNC pruefekollision_ende
    OR BYTE PTR [BP-10],1000b ; Kollision unten rechts merken


pruefekollision_ende:


POP SI
POP DX
POP CX
POP BX
POP AX

MOV DL,[BP-10] ; Ergebnisausgabe

; Stackrahmen zurücksetzen
MOV SP,BP
POP BP
RET
pruefekollision ENDP





; Wertet die Kollision von Balduin mit dem Objekt (DS:SI) aus
; Parameter: DL    = Kollisionsinformationen: Himmel (1.Bit), Diamanten (2.Bit), blockierende Elemente (3.Bit), tötende Elemente (4.Bit)
;            DS:SI = Zeiger auf Objekt-Sprite
; Ausgabe  : CY    = Kollision
kollisionauswerten PROC


; Check ob Kollision mit Himmel geprüft werden soll
TEST DL,0001b ; Himmel-Check
JZ kollisionauswerten_diamanten
  ; Kollisionsprüfung mit Himmel
  CMP BYTE PTR DS:[SI],c_sprite_himmel
  JE kollisionauswerten_kollision


kollisionauswerten_diamanten:
; Check ob Kollision mit Diamanten geprüft werden soll
TEST DL,0010b ; Diamanten-Check
JZ kollisionauswerten_blockierendeelemente
  ; Kollisionsprüfung mit Diamanten
  CMP BYTE PTR DS:[SI],c_animation_spritemin
  JB kollisionauswerten_blockierendeelemente
  CMP BYTE PTR DS:[SI],c_animation_spritemax
  JA kollisionauswerten_blockierendeelemente
  ; Diamant gefunden
  JMP kollisionauswerten_kollision


kollisionauswerten_blockierendeelemente:
; Check ob Kollision mit blockierenden Elementen geprüft werden soll
TEST DL,0100b ; blockierende Elemente-Check
JZ kollisionauswerten_toetendeelemente
  ; Kollisionsprüfung mit blockierenden Elementen
  CMP BYTE PTR DS:[SI],c_sprite_grasboden
  JE kollisionauswerten_kollision
  CMP BYTE PTR DS:[SI],c_sprite_erdboden
  JE kollisionauswerten_kollision
  CMP BYTE PTR DS:[SI],c_sprite_mauer
  JE kollisionauswerten_kollision


kollisionauswerten_toetendeelemente:
; Check ob Kollision mit tötenden Elementen geprüft werden soll
TEST DL,1000b ; tötende Elemente-Check
JZ kollisionauswerten_keinekollision
  ; Kollisionsprüfung mit tötenden Elementen
  CMP BYTE PTR DS:[SI],c_sprite_stachel
  JE kollisionauswerten_kollision
  CMP BYTE PTR DS:[SI],c_sprite_wasser
  JE kollisionauswerten_kollision
  CMP BYTE PTR DS:[SI],c_sprite_wassertief
  JE kollisionauswerten_kollision


kollisionauswerten_keinekollision:
CLC
JMP kollisionauswerten_ende
kollisionauswerten_kollision:
  STC
kollisionauswerten_ende:


RET
kollisionauswerten ENDP





; prüft auf Kollision mit Diamanten, dekrementiert die Diamantenanzahl und ersetzt
; die eingesammelten Diamanten durch Himmel
; Parameter: -
; Ausgabe:   -
diamanteneinsammeln PROC
PUSH AX
PUSH BX
PUSH DX
PUSH SI


; prüft auf Kollision mit Diamanten
MOV AX,balduin_x
MOV BX,balduin_y
MOV DL,0010b ; Diamanten
CALL pruefekollision ; (AX=Balduin X-Pos,BX=Balduin Y-Pos,DL=Kollisionsinfo): DL=Kollision wo (oben links,oben rechts,unten links,unten rechts)
OR DL,DL
JZ diamanteneinsammeln3
  ; Kollision mit Diamant(en)
  ; eingesammelten Diamanten durch Himmel ersetzen
  PUSH DX ; Kollisionsposition zwischenspeichern
  LEA SI,spielfeld
  ; Balduin-X-Position ggf. ins Hauptspielfeld umrechnen
  CMP AX,0
  JNL diamanteneinsammeln8
    ADD AX,spielfeldbreite_px
    JMP diamanteneinsammeln9
  diamanteneinsammeln8:
  CMP AX,spielfeldbreite_px
  JNG diamanteneinsammeln9
    SUB AX,spielfeldbreite_px
  diamanteneinsammeln9:
  PUSH AX
  ; SI um x-Pos von Balduin im Spielfeld verschieben
  XOR DX,DX
  MOV BX,c_spritebreite
  DIV BX
  ADD SI,AX
  ; SI um y-Pos von Balduin im Spielfeld verschieben
  XOR DX,DX
  MOV AX,balduin_y
  MOV BX,c_spritehoehe
  DIV BX
  MUL spielfeldbreite
  ADD SI,AX
  ; je nach Position der Kollision, Diamanten durch Himmel ersetzen
  POP AX ; umgerechnete Balduin-X-Pos im Hauptspielfeld
  POP DX
  TEST DL,0001b ; oben links
  JZ diamanteneinsammeln4
    MOV BYTE PTR DS:[SI],c_sprite_himmel
    DEC ndiamanten ; Diamanten dekrementieren
  diamanteneinsammeln4:
  TEST DL,0010b ; oben rechts
  JZ diamanteneinsammeln5
    PUSH SI
    INC SI
    MOV BX,AX
    AND BX,1111111111110000b ; entspricht quasi div 16 ohne rest - x-pos im spriteraster
    ADD BX,c_spritebreite
    CMP BX,spielfeldbreite_px
    JNE diamanteneinsammeln1
      ; Balduin befindet sich am rechten Spielfeldrand, die rechts eingesammelten Diamanten (lt. pruefekollision)
      ; sind in durch die Zylinderwelt auf der ganz linken Seite des Spielfelds zu finden
      SUB SI,spielfeldbreite
    diamanteneinsammeln1:
    MOV BYTE PTR DS:[SI],c_sprite_himmel
    DEC ndiamanten ; Diamanten dekrementieren
    POP SI
  diamanteneinsammeln5:
  ADD SI,spielfeldbreite
  TEST DL,0100b ; unten links
  JZ diamanteneinsammeln6
    MOV BYTE PTR DS:[SI],c_sprite_himmel
    DEC ndiamanten ; Diamanten dekrementieren
  diamanteneinsammeln6:
  TEST DL,1000b ; unten rechts
  JZ diamanteneinsammeln3
    INC SI
    AND AX,1111111111110000b ; entspricht quasi div 16 ohne rest - x-pos im spriteraster
    ADD AX,c_spritebreite
    CMP AX,spielfeldbreite_px
    JNE diamanteneinsammeln2
      ; Balduin befindet sich am rechten Spielfeldrand, die rechts eingesammelten Diamanten (lt. pruefekollision)
      ; sind in durch die Zylinderwelt auf der ganz linken Seite des Spielfelds zu finden
      SUB SI,spielfeldbreite
    diamanteneinsammeln2:
    MOV BYTE PTR DS:[SI],c_sprite_himmel
    DEC ndiamanten ; Diamanten dekrementieren
diamanteneinsammeln3:


POP SI
POP DX
POP BX
POP AX
RET
diamanteneinsammeln ENDP





; Animiert die Diamanten auf dem Spielfeld
; Parameter: AX    - Animationszähler
;            BX    - Spritenummer
;            DS:SI - Spritepixel
; Ausgabe:   geändertes Spielfeld
;            BX - Änderung der Spritenummer
spielfeldanimieren PROC
PUSH AX
PUSH CX
PUSH SI


CMP BX,c_animation_spritemin
JB spielfeldanimieren1

CMP BX,c_animation_spritemax
JA spielfeldanimieren1

JNE spielfeldanimieren2
  ; wenn bei letztem Sprite angekommen, zum ersten zurücksetzen
  MOV BYTE PTR DS:[SI],c_animation_spritemin
  MOV BX,c_animation_spritemin
  JMP spielfeldanimieren1
spielfeldanimieren2:

  AND AX,c_animation_bildwechsel-1
  OR AX,AX
  JNZ spielfeldanimieren1
    INC BYTE PTR DS:[SI]
    INC BX
spielfeldanimieren1:


POP SI
POP CX
POP AX
RET
spielfeldanimieren ENDP





; richtet den Bildschrim-Ausschnitt anhand der Position von Balduin im Spielfeld aus
screenausrichten PROC
PUSH AX


; X-Pos des Bildschrims ausrichten
MOV AX,balduin_x
SUB AX,c_videobreite/2-c_spritebreite/2
MOV screenpos_x,AX

; Y-Pos des Bildschrims ausrichten
MOV AX,balduin_y
SUB AX,c_videohoehe/2+c_balduin_screenpos_y
; prüft auf Bildschrim-Begrenzung oben
OR AX,AX
JNL screenausrichten1
  MOV screenpos_y,0
  JMP screenausrichten_ende
screenausrichten1:
; prüft auf Bildschrim-Begrenzung unten
CMP AX,maxscreenpos_y
JNG screenausrichten2
  MOV AX,maxscreenpos_y
  MOV screenpos_y,AX
  JMP screenausrichten_ende
screenausrichten2:

; Normalfall:
MOV screenpos_y,AX


screenausrichten_ende:


POP AX
RET
screenausrichten ENDP





; Errechnet den aktuellen Spielfeldausschnitt und legt die entsprechenden Sprites
; in korrekter Anordnung in einem puffer ab.
; Parameter: CX = Frame für Animationszähler
;            DS = Datensegment
spielfelddarstellen PROC
; Stackrahmen initialisieren
PUSH BP
MOV BP,SP
SUB SP,4 ; 4 Bytes Platz fuer lokale Variablen reservieren

; restliche Register sichern
PUSH CX ; Animationszähler sichern

PUSH AX
PUSH BX
PUSH DX
PUSH DI
PUSH SI
PUSH DS
PUSH ES


MOV AX,SEG buffer
MOV ES,AX ; ES auf buffer setzen

XOR AX,AX
MOV [BP-2],AX ; X Pos im Spielfeld INIT
MOV [BP-4],AX ; Y Pos im Spielfeld INIT

XOR DI,DI ; Anfang im buffer-Segement

spielfelddarstellen1:
  LEA SI,spielfeld
  ADD SI,[BP-2]
  MOV AX,spielfeldbreite
  MUL WORD PTR [BP-4]
  ADD SI,AX ; SI enthält den Offset des zu malenden Sprites (also dessen Nummer)

  XOR BH,BH
  MOV BL,DS:[SI] ; läd Nummer der darzustellenden Sprite
  CMP BX,nsprites
  JB spielfelddarstellen3 ; wenn gewünschte Sprite in Datei vorhanden ist
    XOR BX,BX ; sonst zeige Sprite 0 an
  spielfelddarstellen3:

  ; Diamantenanimation..
  MOV AX,[BP-6] ; Animationszähler
  CALL spielfeldanimieren

  ;Spriteposition ermitteln
  MOV AX,c_spritebreite*c_spritehoehe
  MUL BX
  LEA DX,bildpixel
  ADD DX,AX
  MOV SI,DX ; Position der gewünschten Sprite

  ;Y-Position vom Sprite ermitteln
  MOV AX,c_spritehoehe
  MUL WORD PTR [BP-4]
  SUB AX,screenpos_y
  PUSH AX

  ;X-Position vom Sprite ermitteln
  MOV AX,c_spritebreite
  MUL WORD PTR [BP-2] ; x spielfeldpos_x (quasi)
  SUB AX,screenpos_x

  POP BX

  ;weitere Paramter setzen (breite und hoehe des zu malenden Sprites)
  MOV CX,c_spritebreite
  MOV DX,c_spritehoehe

  ;Sprite im buffer ablegen
  CALL kopierebitmapclip ; (DS:SI=Quellbild, ES:DI=Zielbild, AX=X-Position ins Zielbild,
                         ;  BX=Y-Position ins Zielbild, CX=Breite des Quellbildes, DX=Hoehe des Quellbildes)

  ;Sprites malen, die vom Zylinder Gebrauch machen
  PUSH AX
  ADD AX,spielfeldbreite_px
  CALL kopierebitmapclip ; rechts
  POP AX
  SUB AX,spielfeldbreite_px
  CALL kopierebitmapclip ; links

  INC WORD PTR [BP-2]
  MOV AX,[BP-2]
  CMP AX,spielfeldbreite
  JNE spielfelddarstellen2
    ; X Pos im Spielfeld auf 0 setzen..
  	MOV AX,[BP-2]
    XOR AX,AX
    MOV [BP-2],AX

    ; Y Pos im Spielfeld um 1 erhöhen
    MOV AX,[BP-4]
    INC AX
    MOV [BP-4],AX

  spielfelddarstellen2:

  ; Auf Ende prüfen..
  ; zuerst vertikales Ereignis prüfen (trifft nicht so oft ein, wie horizontales, womit man sich dann den Vergleich schenken kann)
  MOV AX,[BP-4]
  CMP AX,spielfeldhoehe
JB spielfelddarstellen1

  ; horizontales Ereignis prüfen
  CMP WORD PTR [BP-2],0 ; 0, da bei x==spielfeldbreite x kurz vorher auf 0 gesetzt wird!
JE spielfelddarstellen1

; Register wiederherstellen
POP ES
POP DS
POP SI
POP DI
POP DX
POP BX
POP AX

POP CX ; Animationszähler wiederherstellen

; Stackrahmen zurücksetzen
MOV SP,BP
POP BP
RET
spielfelddarstellen ENDP





; Kopiert das Balduin-Sprite an der richtigen Position
; in den  Videobuffer
; Parameter: keine
; Ausgabe: aktualisierter Videobuffer
balduindarstellen PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH DI
PUSH SI
PUSH ES


MOV AX,SEG buffer
MOV ES,AX ; ES auf buffer setzen

XOR DI,DI

LEA DX,bildpixel+c_spritebreite*c_spritehoehe*c_sprite_balduin
MOV SI,DX ; Position der Balduin-Sprite

MOV AX,balduin_x
SUB AX,screenpos_x
MOV BX,balduin_y
SUB BX,screenpos_y

MOV CX,c_spritebreite
MOV DX,c_spritehoehe

;Sprite im buffer ablegen
CALL kopierebitmapclip ; (DS:SI=Quellbild, ES:DI=Zielbild, AX=X-Position ins Zielbild,
                         ;  BX=Y-Position ins Zielbild, CX=Breite des Quellbildes, DX=Hoehe des Quellbildes)

POP ES
POP SI
POP DI
POP DX
POP CX
POP BX
POP AX
RET
balduindarstellen ENDP





; Kopiert den Buffer in das Videoram
; Parameter: DS:SI - Quellbuffer
;            ES:DI - Zielbuffer Videoram
kopierepuffer PROC
PUSH CX
PUSH DI
PUSH SI


MOV CX,c_videobreite*c_videohoehe
SHR CX,2 ; wegen DWORD-Kopiervorgang Schleifendurchläufe durch 4 teilen
REP MOVSD


POP SI
POP DI
POP CX
RET
kopierepuffer ENDP





; entfernt alle eingaben aus dem tastaturpuffer, falls eingaben vorhanden
; Parameter: -
; Ausgabe:   -
tastaturpufferleeren PROC
PUSH AX
PUSH BX ; wird von den Funktionen geändert


;Prüfen ob ein Zeichen gedrückt wurde
MOV AH,01h
INT 16h
JZ keinzeichenvorhanden

;Zeichen schlucken
MOV AH,00h
INT 16h

keinzeichenvorhanden:

POP BX
POP AX

RET
tastaturpufferleeren ENDP





; Wartet solange ab, bis der Kathodenstrahl im vertikalen Rücklauf ist
; Parameter: -
; Ausgabe:   -
wartevr PROC
PUSH AX
PUSH DX


MOV DX,c_statusreg ; Befehl laden - Statusregister der Grafikkarte

wartevr1:

IN AL,DX ; Wert der Grafikkarte auslesen

TEST AL,00001000b ; testet, ob Bit 3 gesetzt ist

JZ wartevr1 ; wenn Grafikkarte nicht im vertikalen Rücklauf befindet, wiederholen bis es eintritt


POP DX
POP AX
RET
wartevr ENDP





;Liest eine BMP-Datei ein
;Parameter: DS:DX  = Dateiname
;           ES:DI  = Zielpuffer fuer Bild (Breite, Hoehe, Pixeldaten)
;           ES:BP  = Zielpuffer fuer Palette
;           buffer = Zwischenspeicher
;Ausgabe  : CY = Fehler
;           DX = Fehlermeldung
ladebitmap PROC

;Register sichern
PUSH AX
PUSH BX
PUSH CX
PUSH SI
PUSH DI
PUSH DS

;Datei oeffnen
MOV AX,3D00h  ;Datei zum Lesen oeffnen
INT 21h
JNC lb_header
STC           ;Datei existiert nicht
LEA DX,err_nichtgefunden
JMP lb_ende

;Header lesen
lb_header:
MOV BX,AX
MOV AX,SEG buffer
MOV DS,AX
XOR DX,DX
MOV CX,54  ;Mindestgroesse des Headers
MOV AH,3Fh
INT 21h
CMP AX,CX
JE lb_headerpruefen
STC        ;Header ist zu kurz (=fehlerhaft)
LEA DX,err_keinbmp
JMP lb_ende

;Header pruefen
lb_headerpruefen:
CMP WORD PTR DS:[c_bmp_id],'MB'
JE lb_farbtiefe
STC        ;BMP-ID fehlt im Header
LEA DX,err_keinbmp
JMP lb_ende

;Farbtiefe pruefen
lb_farbtiefe:
CMP BYTE PTR DS:[c_bmp_bitspropixel],8
JE lb_groesse
lb_formatfehler:
STC        ;falsche Farbtiefe
LEA DX,err_falschesformat
JMP lb_ende

;Bitmapgroesse pruefen
lb_groesse:
MOV AX,DS:[c_bmp_bildbreite]  ;Breite pruefen
CMP AX,c_maxbildbreite
JA lb_formatfehler
MOV DX,DS:[c_bmp_bildhoehe]   ;Hoehe pruefen
CMP DX,c_maxbildhoehe
JA lb_formatfehler
PUSH DI                     ;Zeiger auf Zielpuffer merken
STOSW                       ;Breite speichern
MOV ES:[DI],DX              ;Hoehe speichern

;Palette einlesen
;Dateizeiger auf Palettendaten setzen (Offset 14+formatgroesse)
MOV AX,4200h  ;DOS-Funktion 42h (Dateizeiger bewegen), absolut
MOV DX,14     ;Groesse des Dateiheaders
XOR CX,CX
ADD DX,DS:[c_bmp_formatgroesse]
ADC CX,0
INT 21h
;1024 Bytes Palettendaten lesen
MOV DX,54
MOV CX,1024
MOV AH,3Fh
INT 21h
;Palette konvertieren
MOV CX,256
MOV SI,DX
MOV DI,BP
lb_palette:
MOV AL,[SI+2]  ;Rot
SHR AL,2       ;von 8 Bit auf 6 Bit herunterskalieren
STOSB
MOV AL,[SI+1]  ;Gruen
SHR AL,2       ;von 8 Bit auf 6 Bit herunterskalieren
STOSB
MOV AL,[SI]    ;Blau
SHR AL,2       ;von 8 Bit auf 6 Bit herunterskalieren
STOSB
ADD SI,4
LOOP lb_palette

;Pixeldaten einlesen
;Dateizeiger auf Pixeldaten setzen (Offset pixeldaten)
MOV AX,4200h  ;DOS-Funktion 42h (Dateizeiger bewegen), absolut
MOV DX,DS:[c_bmp_pixeldaten]
MOV CX,DS:[c_bmp_pixeldaten+2]
INT 21h
;Rest der Datei einlesen
XOR DX,DX
MOV CX,64000
MOV AH,3Fh
INT 21h
;Pixelzeilen konvertieren (stehen auf dem Kopf und sind auf DWORD aufgefuellt)
POP DI            ;Zeiger auf Zielpuffer wiederherstellen
MOV AX,ES:[DI]    ;Bildbreite
MOV CX,AX
ADD AX,3
AND AX,0FFFCh     ;physikalische Bildbreite in der Datei
MOV DX,ES:[DI+2]  ;Bildhoehe
ADD DI,4
PUSH AX
PUSH DX
DEC DX
MUL DX
MOV SI,AX         ;Zeiger auf letzte Pixelzeile
POP DX
POP AX
lb_pixel:
PUSH CX
REP MOVSB         ;eine Zeile kopieren
POP CX
SUB SI,CX
SUB SI,AX
DEC DX
JNZ lb_pixel

;Datei schliessen
MOV AH,3Eh
INT 21h
CLC

;Register wiederherstellen
lb_ende:
POP DS
POP DI
POP SI
POP CX
POP BX
POP AX
RET
ladebitmap ENDP





; Ermittelt die Anzahl der Sprites, die in der geladenen Bitmap sind
; Bei Fehler wird die Anzahl der Sprits auf 0 gesetzt
; Parameter: DS = Datensegment
; Ausgabe:   DS:nsprites = Anzahl der Sprites
spritesanzahlermitteln PROC
PUSH AX
PUSH BX
PUSH DX


; Anzahl der Sprites in Bilddatei ermitteln
MOV AX,bildhoehe
OR AX,AX
JNZ spritesanzahlermitteln1
	; Bei Bildhöhe = 0 Berechnung mit Ausgabe 0 abbrechen
  MOV nsprites,0
  JMP spritesanzahlermitteln2 ; Berechnung überspringen

spritesanzahlermitteln1:
XOR DX,DX
MOV BX,c_spritehoehe
DIV BX
MOV nsprites,AX ; Anzahl der Sprites in nsprites sichern

spritesanzahlermitteln2:


POP DX
POP BX
POP AX
RET
spritesanzahlermitteln ENDP





; Ermittelt den Dateinamen des nächsten Spielfelds
; Funktion arbeitet nur bis incl. Dateiname level998.bld korrekt!
; Parameter: DS:DI = Dateiname
; Ausgabe:   veränderter Dateiname
;            CY = Fehler: neuer Dateiname nicht vorhanden
naechstesspielfeld PROC
PUSH AX
PUSH DX
PUSH DI


ADD DI,7 ; auf die letzte Ziffer der 3-stelligen Zahl zeigen

naechstesspielfeld1:
  CMP BYTE PTR DS:[DI],'9' ; auf 9 prüfen
  JNE naechstesspielfeld2
  MOV BYTE PTR DS:[DI],'0' ; bei 9 ziffer auf 0 setzen
  DEC DI                   ; nächste Ziffer überprüfen
JMP naechstesspielfeld1

naechstesspielfeld2:
INC BYTE PTR DS:[DI] ; Zahl inkrementieren


; Check ob Datei vorhanden (bzw. ob geöffnet werden kann)
MOV AX,3D00h
POP DX ; übergebenes DI-Register in DX laden
PUSH DX
INT 21h
JC naechstesspielfeld3
  ; Datei vorhanden
  MOV BX,AX ; Handle laden
  MOV AH,3Eh
  INT 21h ; Datei wieder schließen
  CLC
naechstesspielfeld3:


POP DI
POP DX
POP AX
RET
naechstesspielfeld ENDP





;Läd die Informationen aus der Spielfelddatei in den Speicher
;Parameter: DS:DX  = Dateiname
;           ES:DI  = Zielpuffer fuer Spielfeld (Breite, Hoehe, Spielfeld) (Zeiger auf 'spielfeldbreite'!)
;Ausgabe  : CY = Fehler
;           DX = Fehlermeldung
ladespielfeld PROC
PUSH AX
PUSH BX
PUSH CX
PUSH SI
PUSH DI
PUSH DS

;Datei oeffnen
MOV AX,3D00h  ;Datei zum Lesen oeffnen
INT 21h
JNC ls_header
STC           ;Datei existiert nicht
LEA DX,err_nichtgefunden
JMP ls_ende

;Header lesen
ls_header:
MOV BX,AX ; Handle der Datei auf BX kopieren
MOV AX,SEG data
MOV DS,AX
XOR DX,DX
MOV CX,16  ;Mindestgroesse des Headers
MOV AH,3Fh
INT 21h
CMP AX,CX
JE ls_headerpruefen
STC        ;Header ist zu kurz (=fehlerhaft)
LEA DX,err_keinspielfeld
JMP ls_ende

;Header pruefen
ls_headerpruefen:
CMP DWORD PTR DS:[c_bald_id],c_spielfelddateiid
JE ls_groesse
STC        ;BALD-ID fehlt im Header
LEA DX,err_keinspielfeld
JMP ls_ende

ls_formatfehler:
STC        ;Formatfehler ist aufgetreten (falls Sprungmarke genutzt wird)
LEA DX,err_falschesspielfeldformat
JMP ls_ende

;Spielfeldgröße pruefen
ls_groesse:
MOV AX,DS:[c_bald_breite]  ;Breite pruefen
CMP AX,c_maxspielfeldbreite
JA ls_formatfehler
MOV DX,DS:[c_bald_hoehe]   ;Hoehe pruefen
CMP DX,c_maxspielfeldhoehe
JA ls_formatfehler
STOSW                       ;Breite speichern
MOV ES:[DI],DX              ;Hoehe speichern

;Spielfelddaten einlesen
;Dateizeiger auf Spielfelddaten setzen (Offset bald_spritepositionen)
MOV AX,4200h  ;DOS-Funktion 42h (Dateizeiger bewegen), absolut
XOR CX,CX
MOV DX,c_bald_spritepositionen
INT 21h
;Rest der Datei einlesen
MOV AX,spielfeldbreite
MUL spielfeldhoehe
MOV CX,AX
LEA DX,ES:spielfeld
MOV AH,3Fh
INT 21h

; Spielfeldbreite in Pixeln ermitteln
MOV AX,c_spritebreite
MUL spielfeldbreite
MOV spielfeldbreite_px,AX

; Spielfeldbreite in Pixeln ermitteln
MOV AX,c_spritehoehe
MUL spielfeldhoehe
MOV spielfeldhoehe_px,AX

; Maximale vertikale Position des Bildschirmausschnittes ermitteln
MOV AX,c_spritehoehe
MUL spielfeldhoehe
SUB AX,c_videohoehe
MOV maxscreenpos_y,AX


;Datei schliessen
MOV AH,3Eh
INT 21h
CLC


;Register wiederherstellen
ls_ende:
POP DS
POP DI
POP SI
POP CX
POP BX
POP AX
RET
ladespielfeld ENDP





;Schaltet in den Grafikmodus (320x200 Pixel bei 256 Farben)
;Parameter: keine
;Ausgabe  : keine
grafikein PROC
PUSH AX


MOV AX,0013h  ;Funktion 00h, Videomodus 13h
INT 10h


POP AX
RET
grafikein ENDP





;Schaltet zurueck in den Textmodus
;Parameter: keine
;Ausgabe  : keine
grafikaus PROC
PUSH AX


MOV AX,0003h  ;Funktion 00h, Videomodus 03h
INT 10h


POP AX
RET
grafikaus ENDP





;Laedt die DAC-Farbregister mit der angegeben Farbpalette
;Parameter: DS:SI = Palette (256 x 3 Bytes)
;Ausgabe  : keine
aktivierepalette PROC
;Register sichern
PUSH AX
PUSH CX
PUSH DX
PUSH SI

;Nummer des ersten DAC-Registers setzen
MOV DX,c_dac_adrreg  ;Portnummer des Adressregisters
XOR AL,AL
OUT DX,AL

;Palettendaten uebertragen
MOV CX,768  ;256x RGB
INC DX  ;Portnummer des Datenregisters
aktivierepalette1:
LODSB
OUT DX,AL
LOOP aktivierepalette1

;Register wiederherstellen
POP SI
POP DX
POP CX
POP AX
RET
aktivierepalette ENDP





;Gibt einen Text (String) auf dem Bildschirm aus
;Parameter: DS:DX = Adresse des Textes
;Ausgabe  : keine
textausgabe PROC
PUSH AX
MOV AH,09h
INT 21h  ;Text mit DOS-Funktion ausgeben
POP AX
RET
textausgabe ENDP





;Kopiert ein Quellbild in ein Zielbild hinein
;Geht das Quellbild ueber die Raender des Zielbildes hinaus, werden diese
;Teile abgeschnitten
;Parameter: DS:SI = Quellbild
;           ES:DI = Zielbild (videobreite x videohoehe Pixel)
;           AX    = X-Position ins Zielbild
;           BX    = Y-Position ins Zielbild
;           CX    = Breite des Quellbildes
;           DX    = Hoehe des Quellbildes
;Ausgabe  : keine
kopierebitmapclip PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DI
PUSH BP
PUSH DS
PUSH ES


;Parameter sichern
MOV CS:kbtc_y,BX
MOV CS:kbtc_quellbreite,CX

;relevante Breite berechnen
MOV BX,c_videobreite  ;Breite des Zielbildes
XOR BP,BP           ;Anzahl Pixel, die in der Quellbildzeile uebersprungen werden

;linken Rand testen
OR AX,AX
JNS kbitmaptc1
;Bild geht ueber linken Rand hinaus
NEG AX     ;Anzahl Quellbild-Pixel, die links nicht zu sehen sind
SUB CX,AX  ;Anzahl sichtbarer Quellbild-Pixel
JBE kbitmaptcende
ADD SI,AX  ;nicht-sichtbare Pixel am Quellbildanfang ueberspringen
ADD BP,AX  ;nicht-sichtbare Pixel jede Zeile ueberspringen
XOR AX,AX  ;neue X-Position
kbitmaptc1:
SUB BX,AX  ;Anzahl Pixel im Zielbild von X-Position bis zum rechten Rand
JBE kbitmaptcende

;rechten Rand testen
CMP CX,BX
JBE kbitmaptc2
;Bild geht ueber rechten Rand hinaus
ADD BP,CX
SUB BP,BX  ;nicht-sichtbare Pixel jede Zeile ueberspringen
MOV CX,BX  ;Anzahl sichtbarer Quellbild-Pixel
kbitmaptc2:
ADD DI,AX  ;Offset in Zielbild anpassen
;DS:SI = Zeiger auf erstes Quellpixel , ES:DI = Zielposition
;CX = Pixel pro Zeile , BP = Anzahl auszulassender Pixel

;relevante Hoehe berechnen
MOV AX,CS:kbtc_y  ;Y-Position ins Zielbildes

;oberen Rand testen
OR AX,AX
JNS kbitmaptc3
;Bild geht ueber oberen Rand hinaus
NEG AX     ;Anzahl Quellbild-Pixel, die oben nicht zu sehen sind
SUB DX,AX  ;Anzahl sichtbarer Quellbild-Pixel
JBE kbitmaptcende
PUSH DX
MUL CS:kbtc_quellbreite
ADD SI,AX  ;nicht-sichtbare Pixel am Quellbildanfang ueberspringen
POP DX
XOR AX,AX  ;neue Y-Position
kbitmaptc3:
MOV BX,c_videohoehe  ;Hoehe des Zielbildes
SUB BX,AX          ;Anzahl Pixel im Zielbild von Y-Position bis zum unteren Rand
JBE kbitmaptcende

;unteren Rand testen
CMP DX,BX
JBE kbitmaptc4
;Bild geht ueber unteren Rand hinaus
MOV DX,BX  ;Anzahl sichtbarer Quellbild-Pixel
kbitmaptc4:
PUSH DX
MOV DX,c_videobreite
MUL DX
ADD DI,AX  ;Offset in Zielbild anpassen
POP DX

;Bild kopieren
kbitmaptc5:
PUSH CX
REP MOVSB
POP CX
ADD SI,BP           ;nicht-sichtbare Pixel ueberspringen
SUB DI,CX
ADD DI,c_videobreite  ;Zielzeiger auf naechste Zeile
DEC DX
JNZ kbitmaptc5


kbitmaptcende:
POP ES
POP DS
POP BP
POP DI
POP SI
POP DX
POP CX
POP BX
POP AX
RET

kbtc_y DW 0
kbtc_quellbreite DW 0
kopierebitmapclip ENDP





; Tastatur-Interrupt-Handler
; wird von auftretenen Interrupts ausgeführt
int09 PROC
;Register sichern
PUSH AX
PUSH CX
PUSH SI


;Scancode von der Tastatur lesen
IN AL,60h

;pruefen, ob Taste gedrueckt oder losgelassen wurde
MOV AH,AL
AND AH,128  ;Status in Bit 7 maskieren
SHR AH,7    ;Status nach Bit 0 verschieben
XOR AH,1    ;0 = Taste nicht gedrueckt, 1 = Taste gedrueckt

;pruefen, ob Taste fuer das Programm relevant ist
AND AL,127
MOV CX,5
XOR SI,SI
int091:
CMP AL,CS:scancodes[SI]
JNE int092
MOV CS:tastenstatus[SI],AH  ;neuen Status vermerken
int092:
INC SI
LOOP int091


;Register wiederherstellen und alten Interrupt-Handler aufrufen
POP SI
POP CX
POP AX
JMP CS:int09alt

scancodes DB 72,77,80,75,1
tastenstatus DB 0,0,0,0,0
int09alt DD 0
int09 ENDP





; installiert eigenes Tastertur-Handle auf INT09
; Parameter: -
; Ausgabe  : -
intinstallieren PROC
PUSH AX
PUSH DS
PUSH ES


XOR AX,AX
MOV DS,AX ;Segmentadresse der Interrupt-Vektor-Tabelle

;alten INT09-Handler merken
MOV AX,DS:[09h*4]
MOV ES,DS:[09h*4+2] ;Segmentadresse der Interrupt-Routine
MOV WORD PTR CS:int09alt,AX
MOV WORD PTR CS:int09alt[2],ES

;neuen INT09-Handler setzen
CLI
MOV WORD PTR DS:[09h*4],OFFSET int09
MOV DS:[09h*4+2],CS
STI


POP ES
POP DS
POP AX
RET
intinstallieren ENDP





; deinstalliert eigenes Tastertur-Handle von INT09
; Parameter: -
; Ausgabe  : -
intwiederherstellen PROC
PUSH AX
PUSH DS

XOR AX,AX
MOV DS,AX ;Segmentadresse der Interrupt-Vektor-Tabelle

;Deinstallation: alten INT09-Handler wiederherstellen
CLI
MOV AX,WORD PTR CS:int09alt
MOV DS:[09h*4],AX
MOV AX,WORD PTR CS:int09alt[2]
MOV DS:[09h*4+2],AX
STI

POP DS
POP AX
RET
intwiederherstellen ENDP



code ENDS





; Datensegment
data SEGMENT USE16

; initialisierte Variablen


; Fehlermeldungen
err_nichtgefunden           DB 'Die angegebene Datei existiert nicht.',13,10,36
err_keinbmp                 DB 'Die angegebene Datei ist keine BMP-Datei.',13,10,36
err_keinspielfeld           DB 'Die angegebene Datei ist keine BALD-Datei.',13,10,36
err_falschesformat          DB 'Falsches Bildformat (8 Bit Farbtiefe, ...)',13,10,36
err_falschesspielfeldformat DB 'Falsches Spielfeldformat. Konventionen nicht eingehalten!',13,10,36
txt_spielgewonnen           DB 'Herzlichen Glueckwunsch!',13,10,'Sie haben Balduin der Ball durchgespielt!',13,10,36

; Dateiname der Spritedatei
spritedatei DB 'SPRITES.BMP',0

; Spielfeld
spielfelddatei DB 'level001.bld',0


; uninitialisierte Variablen


; Anzahl Sprites in der Datei
nsprites DW ?

; Farbpalette
palette DB 768 DUP (?)

; Bild (Breite, Hoehe, Pixeldaten)
bildbreite DW ?
bildhoehe DW ?
bildpixel DB c_maxbildbreite*c_maxbildhoehe DUP(?)

; Spielfeld
spielfeldbreite DW ?
spielfeldhoehe  DW ?
spielfeld DB c_maxspielfeldbreite*c_maxspielfeldhoehe DUP(?)

spielfeldbreite_px DW ? ; Spielfeldbreite in Pixeln
spielfeldhoehe_px DW ?  ; Spielfeldhoehe in Pixeln

; Balduin
balduin_x DW ?
balduin_y DW ?
sprunghoehe DW ?
maxsprunghoehe DW ?
sprungrichtung DB ?
laufrichtung DB ?

; Diamanten
ndiamanten DW ?

; Bildschirmposition auf dem Spielfeld
; initialisiert mit Startwert!
screenpos_x DW ? ; ganz links
screenpos_y DW ? ; ganz oben

; Maximale vertikale Position des Bildschrimausschnittes
maxscreenpos_y DW ?

data ENDS





; Puffer zum Einlesen der BMP-Datei
buffer SEGMENT USE16
DB 65535 DUP(?)
buffer ENDS





; Stacksegment
stck SEGMENT STACK USE16
DW 200 DUP(?)
stck ENDS





END start
