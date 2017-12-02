# Airbnb web site scraper

## Disclaimers

The script scrapes the Airbnb web site to collect data about the shape of the company's business. No guarantees are made about the quality of data obtained using this script, statistically or about an individual page. So please check your results.

Sometimes the Airbnb site refuses repeated requests. I run the script using a number of proxy IP addresses to avoid being turned away, and that costs money. I am afraid that I cannot help in finding or working with proxy IP services. If you would rather not make the attempt yourself, I will be happy to run collections for you when time allows.

## Prerequisites

- Python 3.4 or later
- PostgreSQL 9.5 or later (as the script uses "INSERT ... ON CONFLICT UPDATE")

or use **Docker**

- Install [Docker CE](https://docs.docker.com/engine/installation/)
- You need python2.7 or python3 and pip
- Run `pip install -r requirements.txt`
- Build containers: `docker-compose build`
- Run containers: `docker-compose up -d`

Now you will have a database container and a exited app container:

```
$ docker ps -a
CONTAINER ID        IMAGE                      COMMAND                   CREATED             STATUS                      PORTS               NAMES
40f5e9727536        airbnbdatacollection_app   "/bin/sh -c \"./sta..."   1 minutes ago       Exited (0) 2 seconds ago                        airbnbdatacollection_app_1
788ed2c37efc        airbnbdatacollection_db    "docker-entrypoint..."    1 minutes ago       Running                      airbnbdatacollection_db_1
```
- You can now run an app container which will be connected to the databases

```
 $ docker run --link airbnbcollect_db_1:db -it -e USER=root --entrypoint /bin/bash airbnbcollect_app
```

## Using the script

You must be comfortable messing about with databases and python to use this.

To run the airbnb.py scraper you will need to use python 3.4 or later and install the modules listed at the top of the file. The difficult one is lxml: you'll have to go to their web site to get it. It doesn't seem to be in the normal python repositories so if you're on Linux you may get it through an application package manager (apt-get or yum, for example). The Anaconda distribution includes lxml and many other packages, and that's now the one 
I use.

Various parameters are stored in a configuration file, which is read in as `$USER.config`. Make a copy of `example.config` and edit it to match your database and the other parameters. The script uses proxies, so if you don't want those you may have to edit out some part of the code.

If you want to run multiple concurrent surveys with different configuration parameters, you can do so by making a copy of your `user.config` file, editing it and running the airbnb.py scripts (see below) with an additional command line parameter. The database connection test would become

    python airbnb.py -dbp -c other.config

This was implemented initially to run bounding-box surveys for countries (maximum zoom of 8) and cities (maximum zoom of 6) at the same time.

### Installing and upgrading the database schema

The airbnb.py script works with a PostgreSQL database. You need to have the PostGIS extension installed. The schema is in the file `postgresql/schema_current.sql`. You need to run that file to create the database tables to start with (assuming both your user and database are named `airbnb`).

For example, if you use psql:

    psql --user airbnb airbnb < postgresql/schema_current.sql

### Preparing to run a survey

To check that you can connect to the database, run

    python airbnb.py -dbp

where python is python3.

Add a search area (city) to the database:

    python airbnb.py -asa "City Name"

This adds a city to the `search_area` table, and a set of neighborhoods to the `neighborhoods` table.

Add a survey description for that city:

    python airbnb.py -asv "City Name"

This makes an entry in the `survey` table, and should give you a `survey_id` value.

### Running a survey 

There are three ways to run surveys:
- by neighbourhood
- by bounding box
- by zipcode

Of these, the bounding box is the one I use most and so is most thoroughly tested. The neighbourhood one is the easiest to set up, so you may want to try that first, but be warned that if Airbnb has not assigned neighbourhoods to the city you are searching, the results can be very incomplete.

For users of earlier releases: Thanks to contributions from Sam Kaufman the searches now save information on the search step, and there is no need to run an `-f` step after running a `-s` or `-sb` or `-sz` search: the information about each room is collected from the search pages.

#### Neighbourhood search

For some cities, Airbnb provides a list of "neighbourhoods", and one search loops over each neighbourhood in turn. If the city does not have neighbourhoods defined by Airbnb, this search will probably underestimate the number of listings by a large amount.

Run a neighbourhood-by-neighbourhood search:

    python airbnb.py -s survey_id

This can take a long time (hours). Like many sites, Airbnb turns away requests (HTTP error 503) if you make too many in a short time, so the script tries waiting regularly. If you have to stop in the middle, that's OK -- running it again picks up where it left off (after a bit of a pause).

#### Zipcode search

To run a search by zipcode (see below for setup):

    python airbnb.py -sz zipcode

Search by zip code requires a set of zip codes for a city, stored in a separate table (which is not currently included). The table definition is 
as follows:

```
CREATE TABLE zipcode (
  zipcode character varying(10) NOT NULL,
  search_area_id integer,
  CONSTRAINT z PRIMARY KEY (zipcode),
  CONSTRAINT zipcode_search_area_id_fkey 
    FOREIGN KEY (search_area_id) 
    REFERENCES search_area (search_area_id)
)
```

#### Bounding box search

To run a search by bounding box:

    python airbnb.py -sb survey_id

Search by bounding box does a recursive geographical search, breaking a bounding box that surrounds a city into smaller pieces, and continuing to search while new listings are identified. This currently relies on adding the bounding box to the search_area table manually. A bounding box for a city can be found by entering the city at the following page:

    http://www.mapdevelopers.com/geocode_bounding_box.php

Then you can update the `search_area` table with a statement like this:

```
UPDATE search_area
SET bb_n_lat = NN.NNN,
bb_s_lat = NN.NNN,
bb_e_lng = NN.NNN,
bb_w_lng = NN.NNN
WHERE search_area_id = NNN
```

Ideally I'd like to automate this process. I am still experimenting with a combination of search_max_pages and search_max_rectangle_zoom (in the user.config file) that picks up all the listings in a reasonably efficient manner. It seems that for a city, search_max_pages=20 and search_max_rectangle_zoom=6 works well.


## Results

The basic data is in the table `room`. A complete search of a given city's listings is a "survey" and the surveys are tracked in table `survey`. If you want to see all the listings for a given survey, you can query the stored procedure survey_room (survey_id) from a tool such as PostgreSQL psql.

```
SELECT *
FROM room
WHERE deleted = 0
AND survey_id = NNN
```

I also create separate tables that have GIS shapefiles for cities in them, and create views that provide a more accurate picture of the listings in a city, but that work is outside the scope of this project.
