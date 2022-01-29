#!/bin/bash

# The previous version of topojson v2 is used in this example thus is "deprecated"; use the most recent topojson v3

# References: 
# https://bl.ocks.org/mbostock/fb6c1e5ff700f9713a9dc2f0fd392c35
# https://bl.ocks.org/mbostock/4573883

# EPSG:2991 Oregon Lambert
# http://www.spatialreference.org/ref/epsg/2991/

# Oregon Albers
# http://www.oregon.gov/geo/Documents/albp.gif
# http://www.oregon.gov/geo/Documents/albl.gif

#PROJECTION='d3.geoAlbers().parallels([42.42, 45.42]).rotate([120, 0])'
PROJECTION='d3.geoConicEqualArea().parallels([42.42, 45.42]).rotate([120, 0])'

# The state FIPS code.
STATE=41

# The American Community Survey (ACS) 5-Year Estimate vintage.
YEAR=2016

# The display size.
WIDTH=960
HEIGHT=1100

CENSUS_KEY='e84593fa935b9c67359c42465f5310a0a1b852ac'

# Download the census block group boundaries.
# Extract the shapefile (.shp) and dBASE (.dbf).
if [ ! -f cb_${YEAR}_${STATE}_bg_500k.shp ]; then
  curl -o cb_${YEAR}_${STATE}_bg_500k.zip \
    "https://www2.census.gov/geo/tiger/GENZ${YEAR}/shp/cb_${YEAR}_${STATE}_bg_500k.zip"
  unzip -o \
    cb_${YEAR}_${STATE}_bg_500k.zip \
    cb_${YEAR}_${STATE}_bg_500k.shp \
    cb_${YEAR}_${STATE}_bg_500k.dbf
fi

# Download the list of counties.
# TODO: compare the curl commands download endpoints and script endpoint, which is correct?
# curl 'http://api.census.gov/data/2014/acs5?get=B01003_001E&for=tract:*&in=state:06' -o cb_2014_06_tract_B01003.json
# curl 'https://api.census.gov/data/2016/acs/acs5?get=B01003_001E&for=tract:*&in=state:41&key=e84593fa935b9c67359c42465f5310a0a1b852ac' -o cb_2016_41_tract_B01003.json
# "https://api.census.gov/data/${YEAR}/acs5?get=B01003_001E&for=block+group:*&in=state:${STATE}&key=${CENSUS_KEY}"
if [ ! -f cb_${YEAR}_${STATE}_counties.json ]; then
  curl -o cb_${YEAR}_${STATE}_counties.json \
    "https://api.census.gov/data/${YEAR}/acs5?get=B01003_001E&for=block+group:*&in=state:${STATE}&key=${CENSUS_KEY}"
fi

# Download the census block group population estimates for each county.
if [ ! -f cb_${YEAR}_${STATE}_bg_B01003.ndjson]; then
  for COUNTY in $(ndjson-cat cb_${YEAR}_${STATE}_counties.json \
    | ndjson-split \
    | tail -n +2 \
    | ndjson-map 'd[2]' \
    | cut -c 2-4); do
  echo ${COUNTY}
  if [ ! -f cb_${YEAR}_${STATE}_${COUNTY}_bg_B01003.json ]; then
    curl -o cb_${YEAR}_${STATE}_${COUNTY}_bg_B01003.json \
      "https://api.census.gov/data/${YEAR}/acs5?get=B01003_001E&for=block+group:*&in=state:${STATE}+county:${COUNTY}&key=${CENSUS_KEY}"
  fi
  ndjson-cat cb_${YEAR}_${STATE}_${COUNTY}_bg_B01003.json \
    | ndjson-split \
    | tail -n +2 \
    >> cb_${YEAR}_${STATE}_bg_B01003.ndjson
  done
fi

# 1. Convert to GeoJSON.
# 2. Project.
# 3. Join with the census data.
# 4. Compute the population density.
# 5. Simplify.
# 6. Compute the county borders.
