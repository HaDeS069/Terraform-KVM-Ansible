#!/bin/bash

# Chemin vers le fichier de playbook Ansible
INVENTORY="/home/hades/project/terraform/Ansible/inventory.yml"

# Stocker temporairement le contenu du fichier inventory.yml
TEMP_FILE=$(mktemp)

# Copier le contenu de INVENTORY dans TEMP_FILE jusqu'à la ligne '[HOSTS]', inclus
awk '/\[HOSTS\]/{print;exit} 1' "$INVENTORY" > "$TEMP_FILE"

# Ajouter la section [HOSTS] s'il n'est pas déjà dans le fichier
if ! grep -q '\[HOSTS\]' "$TEMP_FILE"; then
    echo "[HOSTS]" >> "$TEMP_FILE"
fi

# Pour chaque VM en cours d'exécution, récupérer l'adresse IP
for vm in $(virsh list --name --state-running); do
    ip=$(virsh domifaddr "$vm" | grep -oP '10\.\d+\.\d+\.\d+' | head -n 1)
    if [ ! -z "$ip" ]; then
        echo "$ip" >> "$TEMP_FILE"
        echo "IP ajoutée: $ip" # Affiche l'IP dans le terminal
    fi
done

# Copier le reste du fichier original à partir de la première ligne vide après [HOSTS]
awk '/\[HOSTS\]/ {f=1; next} f && /^$/ {print; f=0} !f' "$INVENTORY" >> "$TEMP_FILE"

# Remplacer le fichier inventory.yml par la version temporaire
mv "$TEMP_FILE" "$INVENTORY"


#########################CONNEXION SSH ##############################
# Extraire les adresses IP de la section [HOSTS]
IPs=$(awk '/\[HOSTS\]/,/^$/' "$INVENTORY" | grep -oP '10\.\d+\.\d+\.\d+')

# Boucle sur chaque adresse IP
for ip in $IPs; do
    # Ajouter l'empreinte digitale de l'hôte au fichier known_hosts
    ssh-keyscan -H "$ip" 2>/dev/null >> ~/.ssh/known_hosts

    # Connexion SSH pour initialiser la première connexion
    if ssh -o StrictHostKeyChecking=no hades@"$ip" 'exit' 2>/dev/null; then
        echo "Connexion SSH OK pour $ip"
    else
        echo "Erreur lors de la connexion SSH à $ip"
    fi
done
