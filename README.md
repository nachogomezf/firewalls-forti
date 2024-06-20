# Automatismo para estandarizar Firewalls Fortinet

Este repositorio proporciona herramientas para obtener configuraciones de los firewalls de la marca Fortinet y compararlas con los estándares definidos. Esto permite identificar las políticas necesarias que faltan y aquellas que están de más.

## Requisitos

Antes de utilizar este repositorio, asegúrate de tener instalado lo siguiente:

- Python 3.8
- Pip
- Git

## Instalación de dependencias



Una vez esté todo instalado, vamos a clonar el repositorio y ejecutar los siguientes scripts

````
git clone git@github.com:nachogomezf/firewalls-forti.git
````

Después de clonar el repositorio, navega a la carpeta del repositorio clonado:

````
cd firewalls-forti
````
Una vez que tienes Python, Pip y Git instalados, necesitas instalar las siguientes librerías. Puedes hacerlo ejecutando el siguiente comando:

```bash
pip install -r requirements.txt
````
Si no se instala correctamente el modulo de `request` habrá que instalarlo mediante el siguiente comando

````
python -m pip install requests

````
cd firewalls-forti/
````

Ahora puedes ejecutar los scripts en el orden indicado:



````
python3 scripts/extract_info.py
python3 scripts/first_compare.py
python3 scripts/second_compare.py
python3 scripts/json2pdf.py

````

Si se prefiere se puede ejecutar el siguiente script para poder ejecutar todos los scripts en el orden indicado

````
./main.bat
````

Esto ejecutará los scripts para obtener los datos del firewall, compararlos y realizar una segunda comparación ya filtrada. Asegúrate de estar en el directorio correcto (donde se encuentra el repositorio clonado) al ejecutar estos comandos.

Podremos ver las políticas que son necesarias y las políticas que sobran en la carpeta:

````
cd /data/output
````
Los archivos son en formato CSV ``politicas_add.csv`` y ``politicas_delete.csv``. Por otro lado también se puede ver en el archivo JSON ``comparation_v2.json`` y en formato PDF denominado ``reporte.pdf``.
