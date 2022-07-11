J'ai réaliser un petit script LUA qui gère l'ouverture et la fermeture des volet de la maison selon différente condition température intérieur extérieur, orientation du soleil, présence ou non de personne dans la maison
si vous avez des idée d’amélioration hésiter surtout pas il y en a plus dans deux tête que dans une


il faudra créé un bouton multiple "Mode volets" avec comme valeur</br>
<img width="359" alt="Bonton mode volet" src="https://user-images.githubusercontent.com/40360509/178256847-f871e2e6-a3a9-449b-8586-b93794f38bc5.png">
<img width="1053" alt="Config bouton mode volet" src="https://user-images.githubusercontent.com/40360509/178256875-dc24e063-bf7b-4773-8356-55bb8f441a0f.png">
</br>
</br>
Differente option sont disponible directement dans le script</br>
-- Opt. 1. Si alarme desactivé (option alarme)</br>
-- => On ouvre les volets designé sinon on les ferme alarme=true</br>
-- Opt. 2. Si pluie détectée (option station meteo)</br>
-- => On ferme les volets correspondant aux fenêtres ouvertes</br>
-- Opt. 3. Commande STOP correspond à un possition du volet</br>
-- => si le volet dispose d'une possition favorite en STOP</br>
-- Opt. 4. Si volets commandable en %</br>
-- => si le volet dispose d'une commande en pourcentage</br>
-- Opt. 5. Si volet donne sur une porte</br>
-- => pas de fermeture du volets identifier porte=true apres le coucher du soleil</br>
-- Opt. 6. Commande de fermeture complète de tous les volets</br>
-- => ouverture / fermeture automatiser de tous les volets selon la valeur de cette commande</br>
-- Opt. 7. Commande presence</br>
-- => si presence detecté ouverture le matin des volets indiquer presence=true si non pas d'ouveture quelque soit le mode</br>
</br>
il faudra penser à ajouter aussi le script sunAzimuth.lua qui ce trouve dans le dossier DZvents pour calucler l'orientation du soleil afin que le mode canicule puisse correctement fonctioner </br>
</br>

