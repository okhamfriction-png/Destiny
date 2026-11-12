// Le pack audio du spectacle (musiques par lieu, bruitages), livré par le Play
// Store à l'installation, avec l'appli : un « asset pack » install-time, hors
// de la limite de 200 Mo du module de base. Rempli par
// `python3 tool/pack_embarque.py` (le contenu n'est pas versionné).
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("destiny_pack")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}
