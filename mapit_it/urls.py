from django.conf.urls import patterns

from django.shortcuts import render

urlpatterns = patterns(
    '',
    (r'^changelog$', render, {'template_name': 'mapit/changelog.html'}, 'mapit_changelog'),
)
