from django.contrib import admin
from django.conf.urls import patterns, include, url
from solid_i18n.urls import solid_i18n_patterns
admin.autodiscover()

handler500 = 'mapit.shortcuts.json_500'

urlpatterns = [
    url(r'^admin/', include(admin.site.urls)),
    url(r'^i18n/', include('django.conf.urls.i18n')),
]

urlpatterns += solid_i18n_patterns('',
    url(r'^', include('mapit.urls')),
)
