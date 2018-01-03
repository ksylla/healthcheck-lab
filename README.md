# HEALTHCHECK for monitoring and initialisation scheduling.

The extension of the `depends_on` option in version 2.1 is not available in version 3.0 and 3.1.

The `depends_on` option of version 3 is the same as in version 2.

# The `haelthcheck` and `condition: service_healthy` options of  version 2.1

The options serve two features

* *monitoring* the service of a container operating properly (`healthy`) or not (`unhaelthy` or `starting`).
* *initialisation scheduling* of containers according to the `depends_on` relation of the services.

These features are both parameterized by the options `interval` `retries` `timeout` and `test`. 
Unfortunately monitoring and initialisation scheduling cannot be specified independently.

Long monitoring intervals may be appropriate and the default value of interval is 30 seconds.
This causes a long delay for the first healthcheck after container start and slows down the intialisation of the stack.

For initialisation scheduling we want to signal a service healthy as soon as possible.
Thus a short interval is useful; many retries may be specified, in order to handle occasional long initialisations. 
But a short interval causes a high frequency of healthchecks at monitoring and a high number of retries
causes high latency of signalling `unhaelthy`.

Currently monitoring cannot be disabled, if initialisation scheduling is required.

# Proposal to extend the healthcheck options

The following options (with example values) may help to separate the handling of an initialisation phase and monitoring.

* `init_delay: 3s` 
   specifies the time to wait after container start until the first healthcheck is executed. 
  * success: the container status changes to `healthy`
  * failure and init\_retries > 0: the container remains in state `starting`
  * failure and init\_retries = 0: the container status changes to `unhaelthy`

* `init_retries: 3` 
   specifies how often at a rate of init\_delay a healthcheck is repeated until the monitoring,,
  * success: the container status changes to `healthy`
  * failure: the container remains in state `starting`
    but if all retries failed, the status is set to `unhealthy`
  
if the option `init_delay` is not specified or set to the value 0s, 
healthchecks for initialisation are disabled.

if the option `interval` is not specified or set to the value 0s, 
monitoring is disabled.

A negative value of `interval` or `init_delay` should be rejected.

# install and run an experiment
```
git clone https://github.com/ksylla/healthcheck-lab.git
cd healthcheck-lab
docker-compose build one
docker-compose up
# stop and kill:
<Ctrl-C><Ctrl-C>
docker-compose down
```
be patient: The log messages of the containers appear after a delay of about 33 seconds.

## LOG of a docker-compose up.  Version 2.1

Three services are started in dependency order `one` -\> `two` -\> `three`

Healthcheck interval of the services `one` and `two` is set to 10s. 
Service `three` runs no healthcheck.

* In service `one` the healthcheck succeeds at the *first* execution, 10s after the start of `one`.
* In service `two` the healthcheck succeeds at the *second* execution, 20s after the start of `two`.

In the log of docker-compose the messages of a container appear in the time sequence of its log events.
But the log events of different containers are not garanteed to appear in correct timely order.

Therefore the docker-compose messages of the example below are sorted by `sort -k 6`:
The log now shows all log events in correct timely order.

Inserted comments lines are marked with `####`.

```
ksylla@ionay:~/BDE/healthcheck-lab$ docker-compose up
Creating network "healthchecklab_default" with the default driver
Creating healthchecklab_one_1
    #### pause of ~10 sec
Creating healthchecklab_two_1
    #### pause of ~22 sec
Creating healthchecklab_three_1
Attaching to healthchecklab_one_1, healthchecklab_two_1, healthchecklab_three_1
one_1    | Thu Mar 16 10:47:27 UTC 2017 --- /run_tail started MAX=-1 : tail -f /tmp/healthcheck.log
    #### wait for          +10 sec
    #### service one: the first healthcheck after one interval succeeds
one_1    | Thu Mar 16 10:47:37 UTC 2017 : 0 > -1 healthcheck exit 0
    #### service one is haelthy: start service two
two_1    | Thu Mar 16 10:47:38 UTC 2017 --- /run_tail started MAX=0 : tail -f /tmp/healthcheck.log
    ####                    +9 sec
one_1    | Thu Mar 16 10:47:47 UTC 2017 : 1 > -1 healthcheck exit 0
    #### service two: the first healthcheck after the first interval fails
two_1    | Thu Mar 16 10:47:48 UTC 2017 : 0 > 0 healthcheck exit 1
    ####                    +9 sec
one_1    | Thu Mar 16 10:47:57 UTC 2017 : 2 > -1 healthcheck exit 0
    #### 31 seconds after docker-compose up.
    #### service two: the second healthcheck after two intervals succeeds
two_1    | Thu Mar 16 10:47:58 UTC 2017 : 1 > 0 healthcheck exit 0
    #### service two is healthy: start service three
    #### At this point in time the previous log messages appear en bloc.
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

