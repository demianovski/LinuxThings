# LinuxThings. Repositorio de herramientas para usuarios y administradores de GNU/Linux.

</br>

## Descripción
Este repositorio contiene herramientas para la gestión de sistemas GNU/Linux, tanto para equipos de escritorio como para servidores. En cada caso será indicado su uso típico. Adaptar a vuestras necesidades.

</br>

### HomeScriptBackup

- Este script está pensado para usar en distribuciones de escritorio, en donde los discos externos se montan automáticamente. En mi caso, uso Fedora, pero en Ubuntu debería funcionar de la misma forma.
- Se respalda un directorio completo. Yo lo uso para respaldar mi home, pero se puede usar para cualquier otro.
- Está pensado para respaldar datos en un disco extraíble, en la forma conecto, backupeo, desconecto.
- Se realizan copias incrementales automáticamente. Cuando se alcanzan las seis copias, el script pregunta si deseás archivar el set completo y comenzar uno nuevo. Se pueden realizar incrementales ilimitadamente, pero es recomendable no extender demasiado la cadena full + incrementales.
- Se archivan automáticamente tres sets completos de forma automática. Se borran los antigüos.

</br>

**Instrucciones de uso**

- Modificar la variable SRC_DIR con la ruta absoluta del directorio que se desea respaldar.
- Modificar la variable USB_LABEL con la etiqueta (label) de la partición del disco externo en donde se van a almacenar las copias.
- Modificar la variable BACKUP_DIR con el nombre del directorio a crear donde se guardarán las copias.

