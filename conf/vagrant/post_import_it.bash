#
# To run after provisioning, move this to a Readfile dedicated to Vagrant
#

workon mapit

# find parents for province and comuni
python manage.py mapit_IT_find_parents --commit

# activate generation
python manage.py mapit_generation_activate --commit
