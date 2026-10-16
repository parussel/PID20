# PID20 Community Edition

Unabhängige Community-Weiterentwicklung des FHEM-Reglers `PID20`. Dateiname `98_PID20.pm` und FHEM-Gerätetyp `PID20` bleiben erhalten, damit bestehende Definitionen weiterverwendet werden können.

> **Status und Risiko:** Dieses Projekt ist derzeit kein offizieller Bestandteil von FHEM. Es wurde automatisiert, isoliert auf einem Raspberry Pi 4 und anschließend mit bestehenden PID20-Definitionen auf einem Raspberry Pi 3 geprüft. Eine breite Erprobung in unterschiedlichen Heizungsanlagen steht noch aus. Vor der Installation bitte eine Sicherung anlegen und die Regelung beobachten. Die Nutzung erfolgt in eigener Verantwortung.

Projektinformationen: [153er-netz.de – Entwicklung](https://153er-netz.de/seiten/entwicklung.html)

## Was ist neu?

- `pidReverseAction=1` kehrt nun auch den D-Anteil um. P, I und D verwenden damit dieselbe Wirkrichtung.
- `pidDIntegration` kann den D-Anteil über mehrere Messzyklen glätten. Dazu wird die Steigung mittels linearer Regression aus dem konfigurierten Verlauf berechnet.
- Der Standardwert `pidDIntegration=1` erhält das bisherige Verhalten.
- Nach erfolgreicher Neuinitialisierung (`INITIALIZED` oder `REREADCFG`) wird die alte D-Historie verworfen.

Beispiel für zehn vorherige Delta-Werte zusätzlich zum aktuellen Wert:

```text
attr <PID20-Device> pidDIntegration 10
```

## Installation und automatische Updates

Die Befehle werden im FHEM-Kommandoeingabefeld ausgeführt.

### 1. Offizielles PID20 quellenspezifisch ausschließen

Der folgende Befehl ergänzt die Regel, ohne vorhandene Ausschlüsse zu überschreiben:

```text
{ my $rule = 'fhem\.de.*:FHEM/98_PID20\.pm'; my @rules = grep { length } split(/[\s,]+/, AttrVal('global','exclude_from_update','')); unless (grep { $_ eq $rule } @rules) { push @rules, $rule; CommandAttr(undef, 'global exclude_from_update '.join(' ', @rules)); } }
save
```

Die Regel passt nur auf das PID20 aus der offiziellen Quelle `fhem.de`. Die Community-Quelle bleibt aktualisierbar.

### 2. Community-Quelle registrieren und installieren

```text
update add https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
update check https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
update all https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
reload 98_PID20
```

Mit `update list` lässt sich die registrierte Quelle kontrollieren. Nach der einmaligen Registrierung wird sie auch bei einem normalen `update` berücksichtigt.

## Erhalt vorhandener Einstellungen und Daten

Die Steuerdatei dieses Repositories enthält ausschließlich `FHEM/98_PID20.pm`. Das Update verändert weder `fhem.cfg` noch `fhem.save`, vorhandene PID20-Definitionen, Attribute oder Readings. Die zusätzliche Ausschlussregel wird an vorhandene Regeln angehängt und anschließend mit `save` gespeichert.

Damit ist technisch abgesichert, dass das bereitgestellte Update nur die Moduldatei ersetzt. Eine aktuelle FHEM-Sicherung bleibt trotzdem empfohlen.

## Rückkehr zum offiziellen PID20

Zuerst die Community-Quelle entfernen:

```text
update delete https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt
```

Dann ausschließlich die zuvor ergänzte Ausschlussregel entfernen und andere Regeln erhalten:

```text
{ my $rule = 'fhem\.de.*:FHEM/98_PID20\.pm'; my @rules = grep { length && $_ ne $rule } split(/[\s,]+/, AttrVal('global','exclude_from_update','')); if (@rules) { CommandAttr(undef, 'global exclude_from_update '.join(' ', @rules)); } else { CommandDeleteAttr(undef, 'global exclude_from_update'); } }
save
```

Anschließend das offizielle Modul wiederherstellen:

```text
update 98_PID20.pm https://fhem.de/fhemupdate/controls_fhem.txt
reload 98_PID20
```

Vor einem Rückwechsel prüfen, ob `pidDIntegration` verwendet wird. Dieses Attribut steht im offiziellen Stand derzeit nicht zur Verfügung.

## Herkunft und Community-Status

Das Modul baut auf dem ursprünglichen FHEM-PID20 auf. Dessen Autoren, Entwicklungsgeschichte und Lizenzhinweise bleiben in der Moduldatei erhalten. Frank Parussel ist Initiator und Bearbeiter dieser Community-Erweiterung, nicht offizieller FHEM-Maintainer. Implementierung, Tests und Dokumentation entstanden mit KI-Unterstützung. Eine spätere Prüfung oder Übernahme geeigneter Änderungen durch die FHEM-Community ist ausdrücklich willkommen.

Die Änderungen knüpfen an die Diskussion im [FHEM-Forum ab Beitrag 420](https://forum.fhem.de/index.php?topic=17067.420) und den [Verbesserungsvorschlag ab Beitrag 435](https://forum.fhem.de/index.php?topic=17067.435) an.

## Tests

Geprüft wurden unter anderem:

- früheres und korrigiertes D-Vorzeichen als Red/Green-Vergleich;
- normale und umgekehrte Wirkrichtung;
- D-Glättung und Begrenzung der Historie;
- gleiche Zeitstempel ohne Division durch null;
- Zurücksetzen der D-Historie nach `REREADCFG`;
- abgefangene Dummy-Aktorbefehle ohne echte Hardware;
- bestehende PID20-Definitionen und Stellmotor-Weitergabe auf einer laufenden FHEM-Installation.

Tests unter Linux mit Perl:

```sh
sh tests/run-tests.sh
```

## Lizenz

GNU General Public License, Version 2 oder – nach eigener Wahl – jede spätere Version (`GPL-2.0-or-later`). Siehe [LICENSE](LICENSE).

---

**English summary:** Independent, unofficial FHEM community extension of PID20. Existing device definitions remain compatible. The release fixes reverse D action, adds optional derivative smoothing, and preserves the original `GPL-2.0-or-later` licensing.
