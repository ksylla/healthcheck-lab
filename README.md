# HEALTHCHECK to be used for controlling the intialisation sequence
#
Offenbar ist die `depends_on` Erweiterung von 2.1 nicht in die Version 3 übernommen worden.

In der Tat sind `haelthcheck` und `condition: service_healthy` zur Steuerung
der Initialisieriungs Reihenfolge noch nicht ausgereift:

Der aller-erste healthcheck wird erst nach dem ersten Ablauf von interval
ausgeführt. Erst dann wechselt der status von start zu haelthy oder not-healthy.
Alle abhängigen container die `service_haelthy` prüfen müssen die interval-Zeit
warten.

Der Vorgabewert von `interval` ist 30sec. 
Das ist eine lange Zeit wenn die Initialisierungs nur wenige Sekunden oder gar
nur Sekundenbruchteile in Anspruch nimmt.

Eine (un-)praktische Konsequenz ist, `interval` auf einen kleinen wert zu
setzen. Das hat den Seiteneffekt, dass `haelthcheck` mit unnötiger oder gar
unerwünschter hoher Frequenz aufgerufen wird
und die logs mit haelthcheck Meldungen aufgefüllt werden.

Ganz abgesehen davon. Es ist nicht möglich nur die Initialisierungsreihenfolge
zu steueren, um dann, nach erfolgreicher Initialisierung des containers auf weitere haelthchecks zu verzichten.

Eine praktische Erweiterung wären folgende Optionen (hier mit beipspielhaften Werten):

* `init-delay: 3s` 
* `init-retries: 3` 
* `interval: 0s` 

Mit init-delay gibt man eine erste Wartezeit bis zum ersten haelthcheck in
der startphase an.

Wenn das fehlschlägt werden maximal init-retries weitere Versuche mit der gleichen
Wartezeit ausgeführt. 
Bis zum ersten erfolgreichen init healthcheck bleibt der
container im Zustand started.

Nach einem erfolgreichen init healthcheck und  
* wenn interval größer 0s ist,
wird die mit interval: retries: usw. spezifizierte haelthcheck Folge gestartet;
* wenn interval auf einen Wert kleiner gleich 0s gesetzt ist,
dann werden keine weiteren haelthchecks mehr ausgeführt.

Wenn kein init healthcheck erfolgreich ist, wird der container in den Zustand
unhealthy gesetzt.

Mit init-retries kann man eine lange Intialisierungsphase definieren,
die aber in der Rate von init-delay geprüft und bei Erfolg mit dem Zustand
healthy beendet wird.

# LOG eines docker-compose up.
healthcheck interval ist für die services 'one' und 'two' auf 10s gesetzt. 
* Im service `one` ist der healthcheck nach 10 sec - beim **ersten** Aufruf - erfolgreich; 
* Im service `two` ist der healthcheck erst nach 20sec - beim **zweiten** Aufruf - erfolgreich. 
Im Log von docker-compose erscheinen die Meldung nur pro container in der korrekten zeitlichen
Reihenfolge.

Die Log-Meldungen des folgenden Beispiels wurden mittels 'sort -k 6' nachträglich
entsprechend der Uhrzeit geordnet. 
Einfügte Kommentare beginnen mit ...

```
ksylla@ionay:~/Projekte/BDE/healthcheck-lab$ docker-compose up
Creating network "healthchecklab_default" with the default driver
Creating healthchecklab_one_1
... wait for ~10sec
Creating healthchecklab_two_1
... wait for ~22sec
Creating healthchecklab_three_1
Attaching to healthchecklab_one_1, healthchecklab_two_1, healthchecklab_three_1
one_1    | Thu Mar 16 10:47:27 UTC 2017 --- /run_tail started MAX=-1 : tail -f /tmp/healthcheck.log
    ...                    +10 sec
one_1    | Thu Mar 16 10:47:37 UTC 2017 : 0 > -1 healthcheck exit 0
two_1    | Thu Mar 16 10:47:38 UTC 2017 --- /run_tail started MAX=0 : tail -f /tmp/healthcheck.log
    ...                     +9 sec
one_1    | Thu Mar 16 10:47:47 UTC 2017 : 1 > -1 healthcheck exit 0
two_1    | Thu Mar 16 10:47:48 UTC 2017 : 0 > 0 healthcheck exit 1
    ...                     +9 sec
one_1    | Thu Mar 16 10:47:57 UTC 2017 : 2 > -1 healthcheck exit 0
two_1    | Thu Mar 16 10:47:58 UTC 2017 : 1 > 0 healthcheck exit 0
    ... ### 31 seconds after start.
    ... ### At this point in time the previous log messages appear eventually en bloc.
three_1  | Thu Mar 16 10:47:58 UTC 2017 --- /run_date started
three_1  | Thu Mar 16 10:48:01 UTC 2017 --- /run_date
three_1  | Thu Mar 16 10:48:04 UTC 2017 --- /run_date
one_1    | Thu Mar 16 10:48:07 UTC 2017 : 3 > -1 healthcheck exit 0
three_1  | Thu Mar 16 10:48:07 UTC 2017 --- /run_date
two_1    | Thu Mar 16 10:48:08 UTC 2017 : 2 > 0 healthcheck exit 0
three_1  | Thu Mar 16 10:48:10 UTC 2017 --- /run_date
three_1  | Thu Mar 16 10:48:13 UTC 2017 --- /run_date
three_1  | Thu Mar 16 10:48:16 UTC 2017 --- /run_date
two_1    | Thu Mar 16 10:48:18 UTC 2017 : 3 > 0 healthcheck exit 0
one_1    | Thu Mar 16 10:48:18 UTC 2017 : 4 > -1 healthcheck exit 0
```

