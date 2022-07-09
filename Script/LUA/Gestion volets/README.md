J'ai réaliser un petit script LUA qui gère l'ouverture et la fermeture des volet de la maison selon différente condition température intérieur extérieur, orientation du soleil, présence ou non de personne dans la maison
si vous avez des idée d’amélioration hésiter surtout pas il y en a plus dans deux tête que dans une


il faudra créé un bouton multiple "Mode volets" avec comme valeur
nuveau / nom
0 / manuel
10 / normal
20 / tardif
30 / canicule


Differente option sont disponible directement dans le script
-- Opt. 1. Si alarme desactivé (option alarme)
-- => On ouvre les volets designé sinon on les ferme alarme=true
-- Opt. 2. Si pluie détectée (option station meteo)
-- => On ferme les volets correspondant aux fenêtres ouvertes
-- Opt. 3. Commande STOP correspond à un possition du volet
-- => si le volet dispose d'une possition favorite en STOP
-- Opt. 4. Si volets commandable en %
-- => si le volet dispose d'une commande en pourcentage
-- Opt. 5. Si volet donne sur une porte
-- => pas de fermeture du volets identifier porte=true apres le coucher du soleil
-- Opt. 6. Commande de fermeture complète de tous les volets
-- => ouverture / fermeture automatiser de tous les volets selon la valeur de cette commande
-- Opt. 7. Commande presence
-- => si presence detecté ouverture le matin des volets indiquer presence=true si non pas d'ouveture quelque soit le mode