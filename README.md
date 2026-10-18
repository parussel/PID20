# PID20 Community Edition für FHEM

Eigenständige Community-Erweiterung des FHEM-Reglers `PID20`. Dateiname
`98_PID20.pm` und Gerätetyp `PID20` bleiben erhalten, damit bestehende
Definitionen weiterverwendet werden können.

> **Status und Hinweis:** Kein offizieller Bestandteil von FHEM. Das Modul
> wurde automatisiert und im praktischen FHEM-Betrieb geprüft; eine breite
> Erprobung an unterschiedlichen Anlagen steht noch aus. Vor der Installation
> eine Sicherung erstellen und die Regelung beobachten. Nutzung in eigener
> Verantwortung.

Projektinformationen: [153er-netz.de – Entwicklung](https://153er-netz.de/seiten/entwicklung.html)

## Änderungen

- `pidReverseAction=1` kehrt nun auch den D-Anteil um. P, I und D verwenden
  dadurch dieselbe Wirkrichtung.
- `pidDIntegration` kann den D-Anteil über mehrere Messzyklen glätten. Die
  Steigung wird dafür mittels linearer Regression aus dem Verlauf berechnet.
- Der Standardwert `pidDIntegration=1` erhält das bisherige Verhalten.
- Nach erfolgreicher Neuinitialisierung (`INITIALIZED` oder `REREADCFG`) wird
  die vorherige D-Historie verworfen.

Beispiel für zehn vorherige Delta-Werte zusätzlich zum aktuellen Wert:

```text
attr <PID20-Device> pidDIntegration 10
```

## Installation und Updates

Führe die Befehle einzeln im FHEM-Kommandoeingabefeld aus und warte jeweils die
Rückmeldung ab. Erstelle vorher eine aktuelle FHEM-Sicherung.

### Offizielles PID20 gezielt vom Update ausschließen

Prüfe zunächst den bestehenden Wert:

```text
{ 'WERT: '.AttrVal('global','exclude_from_update','NICHT_GESETZT') }
```

Wenn die folgende Regel noch nicht enthalten ist, füge sie hinzu. Sie betrifft
ausschließlich `FHEM/98_PID20.pm` von der offiziellen Quelle `fhem.de`:

```text
attr -a global exclude_from_update fhem\.de.*:FHEM/98_PID20\.pm
```

Danach speichern und erneut kontrollieren:

```text
save
```

```text
{ 'WERT: '.AttrVal('global','exclude_from_update','NICHT_GESETZT') }
```

Andere Update-Ausschlüsse bleiben erhalten. Die Community-Quelle ist davon nicht
betroffen.

### Community-Version installieren

```text
update add https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
```

```text
update check https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
```

Prüfe, dass die Vorschau ausschließlich `FHEM/98_PID20.pm` aufführt. Wenn sie
stimmt, installiere die Datei:

```text
update all https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
```

FHEM danach neu starten:

```text
shutdown restart
```

Das Update ersetzt nur die Moduldatei; bestehende Definitionen, Attribute,
Readings und FHEM-Konfiguration werden von der Steuerdatei nicht verändert.

## Rückkehr zum offiziellen Modul

Entferne zuerst die Community-Updatequelle:

```text
update delete https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
```

Entferne danach ausschließlich die zuvor ergänzte Ausschlussregel und speichere
die Änderung:

```text
attr -r global exclude_from_update fhem\.de.*:FHEM/98_PID20\.pm
```

```text
save
```

Stelle anschließend das offizielle Modul wieder her und starte FHEM neu:

```text
update 98_PID20.pm https://fhem.de/fhemupdate/controls_fhem.txt
```

```text
shutdown restart
```

Vor einem Rückwechsel prüfen, ob `pidDIntegration` verwendet wird; dieses
Attribut ist im offiziellen Stand möglicherweise nicht verfügbar.

## Herkunft und Lizenz

Dieses Modul baut auf dem ursprünglichen FHEM-PID20 auf. Die ursprünglichen
Herkunfts- und Lizenzhinweise stehen im Modul. Die Community-Erweiterung ist
eigenständig und nicht offiziell von FHEM übernommen.

Lizenz: GNU General Public License, Version 2 oder – nach eigener Wahl – eine
spätere Version (`GPL-2.0-or-later`). Siehe [LICENSE](LICENSE).
