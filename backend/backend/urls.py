from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

def home(request):
    return HttpResponse("Todo App Backend Running Successfully 🚀")

urlpatterns = [
    path('', home, name='home'),
    path('admin/', admin.site.urls),
    path('api/', include('users.urls')),
    path('api/', include('tasks.urls')),
]