#!/bin/bash

# Definir variables
SRC_DIR="/home/usuario"
USB_LABEL="PARTICION01"
BACKUP_DIR="PC_casa"
ARCHIVE_DIR="archives"
SNAPSHOT_FILE="backup.snar"
BUFFER_SIZE_GB=5

# Encontrar el punto de montaje de la unidad USB por su etiqueta
DEST_DIR=$(lsblk -o LABEL,MOUNTPOINT | grep "$USB_LABEL" | awk '{print $2}')

# Verificar si la unidad USB está montada
if [ -z "$DEST_DIR" ]; then
    echo "Error: La unidad USB con etiqueta $USB_LABEL no está montada."
    exit 1
else
    echo "Unidad USB encontrada en: $DEST_DIR"
fi

# Definir la ruta completa del respaldo
FULL_DEST_DIR="${DEST_DIR}/${BACKUP_DIR}"

# Crear el directorio de respaldo si no existe
if [ ! -d "$FULL_DEST_DIR" ]; then
    echo "Creando directorio de respaldo: $FULL_DEST_DIR"
    mkdir -p "$FULL_DEST_DIR"
fi

echo "El destino del respaldo está establecido en: $FULL_DEST_DIR"

# Validar el espacio disponible antes del respaldo
echo "Validando el espacio disponible para el respaldo..."

# Calcular el tamaño del directorio fuente (en KB)
SRC_SIZE=$(du -sk "$SRC_DIR" | awk '{print $1}')
SRC_SIZE_GB=$((SRC_SIZE / 1024 / 1024))

# Obtener el espacio disponible en el destino (en KB)
AVAILABLE_SPACE=$(df -k "$DEST_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

# Calcular el espacio requerido incluyendo el buffer de 5GB
REQUIRED_SPACE=$((SRC_SIZE_GB + BUFFER_SIZE_GB))

echo "Tamaño del directorio fuente: ${SRC_SIZE_GB} GB"
echo "Espacio disponible en el destino: ${AVAILABLE_SPACE_GB} GB"
echo "Espacio requerido (incluyendo buffer): ${REQUIRED_SPACE} GB"

if [ "$AVAILABLE_SPACE_GB" -lt "$REQUIRED_SPACE" ]; then
    echo "Advertencia: No hay suficiente espacio disponible para el respaldo."
    read -p "¿Deseas proceder de todos modos? (sí/no) " USER_RESPONSE
    if [ "$USER_RESPONSE" != "sí" ]; then
        echo "Respaldo cancelado debido a espacio insuficiente."
        exit 1
    fi
fi

# Buscar el respaldo completo más reciente
FULL_BACKUP=$(ls -t ${FULL_DEST_DIR}/full-backup-*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$FULL_BACKUP" ]; then
    echo "No se encontró ningún respaldo completo. El próximo respaldo será completo."
    NEXT_BACKUP_TYPE="full"
else
    echo "Respaldo completo más reciente encontrado: $FULL_BACKUP"
    NEXT_BACKUP_TYPE="incremental"
fi

# Contar los respaldos incrementales relacionados con el respaldo completo
INCREMENTAL_COUNT=$(ls ${FULL_DEST_DIR}/incremental-backup-*.tar.gz 2>/dev/null | wc -l)

if [ "$INCREMENTAL_COUNT" -ge 6 ]; then
    echo "Se encontraron más de seis respaldos incrementales para este conjunto de respaldo."
    read -p "¿Quieres iniciar un nuevo conjunto de respaldo completo o continuar con incremental (f/i)? " USER_CHOICE
    if [ "$USER_CHOICE" == "f" ]; then
        NEXT_BACKUP_TYPE="full"
    else
        NEXT_BACKUP_TYPE="incremental"
    fi
fi

echo "El siguiente tipo de respaldo será: $NEXT_BACKUP_TYPE"

# Realizar el respaldo (Completo o Incremental)
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

if [ "$NEXT_BACKUP_TYPE" == "full" ]; then
    # Realizar respaldo completo
    echo "Realizando respaldo completo..."
    FULL_BACKUP_FILE="${FULL_DEST_DIR}/full-backup-${TIMESTAMP}.tar.gz"
    
    # Usar pv para mostrar barra de progreso
    tar -cf - --listed-incremental=${FULL_DEST_DIR}/$SNAPSHOT_FILE "$SRC_DIR" | pv -s $(du -sb "$SRC_DIR" | awk '{print $1}') | gzip > "$FULL_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo "Respaldo completo realizado: $FULL_BACKUP_FILE"
    else
        echo "Error: Fallo en el respaldo completo."
        exit 1
    fi
else
    # Realizar respaldo incremental
    echo "Realizando respaldo incremental..."
    INCREMENTAL_BACKUP_FILE="${FULL_DEST_DIR}/incremental-backup-${TIMESTAMP}.tar.gz"
    
    # Usar pv para mostrar barra de progreso
    tar -cf - --listed-incremental=${FULL_DEST_DIR}/$SNAPSHOT_FILE "$SRC_DIR" | pv -s $(du -sb "$SRC_DIR" | awk '{print $1}') | gzip > "$INCREMENTAL_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo "Respaldo incremental realizado: $INCREMENTAL_BACKUP_FILE"
    else
        echo "Error: Fallo en el respaldo incremental."
        exit 1
    fi
fi

# Archivar el conjunto de respaldo actual solo si hay más de seis incrementales
if [ "$NEXT_BACKUP_TYPE" == "full" ] && [ "$INCREMENTAL_COUNT" -ge 6 ]; then
    echo "Archivando el conjunto de respaldo actual..."

    # Definir la ruta del archivo dentro de PC_casa
    ARCHIVE_PATH="${FULL_DEST_DIR}/${ARCHIVE_DIR}"
    if [ ! -d "$ARCHIVE_PATH" ]; then
        echo "Creando directorio de archivos: $ARCHIVE_PATH"
        mkdir -p "$ARCHIVE_PATH"
    fi

    # Archivar el respaldo completo y los incrementales relacionados, excluyendo el directorio "archives"
    TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
    ARCHIVE_FILE="${ARCHIVE_PATH}/backup-set-${TIMESTAMP}.tar"

    tar --exclude="${ARCHIVE_PATH}" -cvpf "$ARCHIVE_FILE" -C "$FULL_DEST_DIR" .

    if [ $? -eq 0 ]; then
        echo "Conjunto de respaldo archivado con éxito: $ARCHIVE_FILE"

        # Limpiar el conjunto de respaldo anterior
        rm -f ${FULL_DEST_DIR}/full-backup-*.tar.gz ${FULL_DEST_DIR}/incremental-backup-*.tar.gz

        # Limpiar el archivo snapshot
        echo "Eliminando archivo snapshot..."
        rm -f "${FULL_DEST_DIR}/${SNAPSHOT_FILE}"
    else
        echo "Error: Fallo al archivar el conjunto de respaldo."
        exit 1
    fi

    # Mantener solo los últimos tres conjuntos archivados
    ARCHIVE_COUNT=$(ls ${ARCHIVE_PATH}/backup-set-*.tar 2>/dev/null | wc -l)

    if [ "$ARCHIVE_COUNT" -gt 3 ]; then
        echo "Limpiando conjuntos de respaldo archivados antiguos..."
        ls -t ${ARCHIVE_PATH}/backup-set-*.tar | tail -n +4 | xargs rm -f
        echo "Conjuntos de respaldo antiguos eliminados."
    fi
fi
