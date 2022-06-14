# Shyrel

This repository holds a set of utils for the relocability of SHYFEM.

## Usage

To download the forcing for the new area, you need to:

1. Create and compile a configuration file for the desired area
2. Invoke `shyrel.sh`

More in detail, you should create the configuration file starting from the `shyrel_TEMPLATE.conf` included in the repository. Set all the variables for your use case, then you're good to go. The template is actually a basic example pivoting the area of Corfu island.

Once the config file is ready, you can invoke `shyrel.sh` with:
```
$ ./shyrel.sh --conf=shyrel.conf
```

In this way, the script will produce:
* 8 days of analysis (daily mean)
* one day of simulation (daily mean)
* 11 days of forecast (daily mean)

If we want to force the production date, we can invoke the script with:

```
$ ./shyrel.sh --conf=shyrel.conf --day=20220104
```

## Something more...
The `shyrel.sh` script invokes three scripts (one for analysis, one for the simulation, the last for forecast). They can be invoked separately with one of the following:
```
$ ./down_an.sh --conf=shyrel.conf
$ ./down_sim.sh --conf=shyrel.conf
$ ./down_fcst.sh --conf=shyrel.conf
```

## Download ECMWF forcings

To download ECMWF forcings, we need to execute the script `ecmwf_forcings.sh` in this way:

```
$ ./ecmwf_forcings.sh --conf=shyrel.conf --day=20220104
```

This script will be soon integrated into shyrel.