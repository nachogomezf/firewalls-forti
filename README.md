# Automatismo para estandarizar Firewalls Fortinet

Este repositorio proporciona herramientas para obtener configuraciones de los firewalls de la marca Fortinet y compararlas con los estándares definidos. Esto permite identificar las políticas necesarias que faltan y aquellas que están de más.

## Requisitos

Antes de utilizar este repositorio, asegúrate de tener instalado lo siguiente:

- Python 3.8
- Pip
- Git

## Instalación de dependencias

Una vez que tienes Python, Pip y Git instalados, necesitas instalar las siguientes librerías. Puedes hacerlo ejecutando el siguiente comando:

```bash
pip install -r requirements.txt
````

Una vez esté todo instalado, vamos a clonar el repositorio y ejecutar los siguientes scripts

````
git clone git@github.com:nachogomezf/firewalls-forti.git
````

Después de clonar el repositorio, navega a la carpeta del repositorio clonado:

````
cd firewalls-forti
````
Hay que tener en cuenta que hay que modificar el archivo ``vars_globales.json`` indicando el ``token`` e ``ip`` del firewall.

Este archivo se encuentra en la ruta ``firewalls-forti/data/info``.

````
cd firewalls-forti/data/info
````

Ahora puedes ejecutar los scripts en el orden indicado:



````
python3 scripts/script.py
python3 scripts/compare.py
python3 scripts/prueba.py
````

Esto ejecutará los scripts para obtener los datos del firewall, compararlos y realizar una segunda comparación ya filtrada. Asegúrate de estar en el directorio correcto (donde se encuentra el repositorio clonado) al ejecutar estos comandos.

Podremos ver las políticas que son necesarias y las políticas que sobran en la carpeta:

````
cd /data/output
````
Los archivos son en formato CSV ``politicas_add.csv`` y ``politicas_delete.csv``. Por otro lado también se puede ver en el archivo JSON ``comparation_v2.json``.
