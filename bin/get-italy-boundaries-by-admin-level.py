#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This script fetches all administrative and political boundaries from
# OpenStreetMap and writes them out as KML.

from __future__ import print_function

import os
import re
import sys

from django.utils.encoding import smart_str

from boundaries import (
    mkdir_p, get_italy_query_relations_and_ways, get_from_overpass, get_name_from_tags, parse_xml_minimal,
    UnclosedBoundariesException)
from generate_kml import get_kml_for_osm_element
__author__ = 'guglielmo'

if len(sys.argv) > 2:
    print("Usage: %s [FIRST-MAPIT_TYPE]" % (sys.argv[0],), file=sys.stderr)
    sys.exit(1)

dir = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(dir, '..', 'data')


def replace_slashes(s):
    return re.sub(r'/', '_', s)

mapit_type_to_tags = {
    # Administrative boundaries, each with a numbered admin_level:
    # http://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative
    # Only those interesting for Italy are considered
    'O04': {'boundary': 'administrative', 'admin_level': '4', },
    'O06': {'boundary': 'administrative', 'admin_level': '6'},
    'O08': {'boundary': 'administrative', 'admin_level': '8'},
    'O09': {'boundary': 'administrative', 'admin_level': '9'},
    'O10': {'boundary': 'administrative', 'admin_level': '10'},
    'O11': {'boundary': 'administrative', 'admin_level': '11'},
}

for mapit_type, required_tags in sorted(mapit_type_to_tags.items()):

    print("Fetching data for MapIt type", mapit_type)

    file_basename = mapit_type + ".xml"
    output_directory = os.path.join(data_dir, "cache-with-political")
    query = get_italy_query_relations_and_ways(required_tags)
    print("Query:\n\n", query)
    data = get_from_overpass(query, file_basename)


    level_directory = os.path.join(output_directory, mapit_type)
    mkdir_p(level_directory)

    def handle_top_level_element(element_type, element_id, tags):

        for required_key, required_value in required_tags.items():

            if required_key not in tags:
                return
            if tags[required_key] != required_value:
                return

        name = get_name_from_tags(tags, element_type, element_id)

        print("Considering admin boundary:", smart_str(name))

        try:

            basename = "%s-%s-%s" % (element_type,
                                     element_id,
                                     replace_slashes(name))

            filename = os.path.join(level_directory, "%s.kml" % (basename,))

            if not os.path.exists(filename):

                kml, _ = get_kml_for_osm_element(element_type, element_id)
                if not kml:
                    print("      No data found for %s %s" % (element_type, element_id))
                    return

                print("      Writing KML to", smart_str(filename))
                with open(filename, "w") as fp:
                    fp.write(kml)

        except UnclosedBoundariesException:
            print("      ... ignoring unclosed boundary")

    parse_xml_minimal(data, handle_top_level_element)
