--[[
name : Genstion_vollets.lua
auteur : Max-MT007
Date de mise à jour : 09/09/2022
date de création : 29/03/2022
Principe : permet d'automatiser la gestion des volets roulants 
en fonction de l'heure de levé et couché du soleil, Temperature, pluie, alarme
]]--
----------------------------------------------------------------------
-- Script d'action des scripts de gestion des volets en fonction de --
----------------------------------------------------------------------
--   1. Mode Manuel
--       => Si activé alors Désactive toute les automatisation du script
--       seul les commande manuel, opt alarme, pluie
--   2. Mode Normal
--        Ouverture volets au lever du soleil / Fermeture au coucher
--        Si option STOP Fermeture en stop apres le coucher et Fermeture complète apres le delai
--   3. Mode Tardif
--        Ouverture volets salon le matin uniquement si présence détectée
--   4. Mode Canicule
--      => Si activé alors
--        Tous les jours, ouverture volets pieces principale 1h30 plus tôt, Fermeture volets pieces principale/chambre 2h plus tard que le lever ou coucher du soleil
--        Si temp dehors < chambre, alors ouvre les volets chambres sinon on les ferme
--        Fermeture et ouverture des volets avec azimute indiqué en fonction de l'orientation du soleil pour garder de la luminositer dans la maison 
--        indiqué le temps de fermeture partiel souhaiter pour chaque volets si pas indiquer fermeture complète
--
--   Opt. 1. Si alarme desactivé (option alarme)  
--       => On ouvre les volets designé sinon on les ferme alarme=true
--   Opt. 2. Si pluie détectée (option station meteo)
--       => On ferme les volets correspondant aux fenêtres ouvertes
--   Opt. 3. Commande STOP correspond à un possition du volet
--       => si le volet dispose d'une possition favorite en STOP 
--   Opt. 4. Si volets commandable en % 
--       => si le volet dispose d'une commande en pourcentage
--   Opt. 5. Si volet donne sur une porte
--       => pas de fermeture du volets identifier porte=true apres le coucher du soleil
--   Opt. 6. Commande de fermeture complète de tous les volets
--       => ouverture / fermeture automatiser de tous les volets selon la valeur de cette commande
--   Opt. 7. Commande presence
--       => si presence detecté ouverture le matin des volets indiquer presence=true si non pas d'ouveture quelque soit le mode

----------------------------------------------------------------------

--------------------------------------------
------------ Variables à éditer ------------
-------------------------------------------- 

local url = '127.0.0.1:8080'                            -- user:pass@ip:port de domoticz
local debugging = false                                 -- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
local script_actif = true                               -- active (true) ou désactive (false) ce script simplement
local sonde_ext = 'Exterieur'                           -- nom de la sonde de température extérieure
--local lumiere = 'luminosité exterieur'                  -- tonumber(otherdevices_svalues['Lux']) -- nom du bloc Lux de wheather underground
--local lux_max = tonumber(90000)                         -- seuil à parti duquel on ferme les volets en pleine journée
local mode_volets = 'Mode volets'                        -- selecteur mode des volets (Manuel, Normal, Tardif, Canicule)
local delai_sus_tarif = tonumber(60)                    -- delai en minites ajouté a tous les autre delais en mode Tardif
local delai_avant_leve_soleil = tonumber(75)            -- délai en minutes pour l'ouverture des volets avant levé du soleil mode canicule & fermeture des volets des chambre si ouvert
local delai_apres_leve_soleil = tonumber(30)            -- délai en minutes pour l'ouverture des volets après levé du soleil
local delai_avant_couche_soleil = tonumber(45)          -- délai en minutes pour l'ouverture des volets avant couché du soleil mode canicule 
local delai_apres_couche_soleil = tonumber(30)          -- délai en minutes pour la fermeture des volets après couché du soleil
local delai_closed_apres_couche_soleil = tonumber(90)   -- délai en minutes pour la fermeture complète des volets après couché du soleil
local delai_on_off = tonumber(10)                       -- délai minimum en minutes pour la réouverture des volets après fermeture
local min_volet_matin_hh = tonumber(7)                  -- heure minimum pour que les volets souvre la matin
local min_volet_matin_mm = tonumber(30)                        
local azimute_sun = 'Azimut du soleil'                  -- variable qui donne l'orientation du soleil par rapport au nord 
local elevation_sun = 'Altitude du soleil'              -- variable qui donne l'levation du soleil dans le ciel

------- option possible -------
local option_alarme =  true 
local option_pluie = true 
local device_pluie = 'Pluie'
local option_stop = true
local option_percente = false
local option_cmd_manu = true
local device_cmd_closed = 'BP chambre'
local value_cmd_closed = "ferme tous les vollets / eteint les lumieres"
local value_cmd_opened = "ouvre les volets"
local device_presence = "iphone max"
local value_presence = "On"

--------------------------------------------
-- Tableau des volets
--------------------------------------------
local les_volets = {};
-- 
-- type de pieces : chambre, principale, service, eau
-- exemple pièces principale (salon, salle à manger, salle de jeux, bureau), eau (cuisine, salle de bain), de service (couloir, toilettes, hall, etc.)
-- Possibilité d'ajouter des équipements en relation, comme température piece, etat ouverture fenetre, etc (séparé par une  virgule)
-- exemple principale les_volets[#les_volets+1] = {volet="Salon sur Jardin", piece="principale" Type="Somfy", absent=false, pieces="principale", azimut=285, times=10}
-- option aditionel : temperature="Temperature Salon" / fenetre="Fenetre Salon sur Jardin" / alarme=true

-- 1ere volet : nom du device volet 1
les_volets[#les_volets+1] = {volet="Volet salon 1", piece="principale", Type="somfy", presence=false, fenetre="Fenetre salon 1", porte=false, pluie=true, azimut=90, times=8.5, alarme=false} 
-- 2eme volet : nom du device volet 2 
les_volets[#les_volets+1] = {volet="Volet salon 2", piece="principale", Type="somfy", presence=false, fenetre="Fenetre salon 2", porte=false, pluie=true, azimut=90, times=8.5, alarme=false} 
-- 3eme volet : nom du device volet 3
les_volets[#les_volets+1] = {volet="Volet salle a manger", piece="principale", Type="somfy", presence=false, fenetre="Fenetre salle a manger", porte=false, pluie=true, azimut=180, times=13, alarme=false}
-- 4eme volet : nom du device volet 4 
les_volets[#les_volets+1] = {volet="Volet terrasse", piece="eau", Type="somfy", presence=true, fenetre="Porte cuisine", porte=true, pluie=false, alarme=true}
-- 5eme volet : nom du device volet 5 
les_volets[#les_volets+1] = {volet="Volet chambre", piece="chambre", Type="somfy", presence=false, fenetre="Fenetre chambre", porte=false, pluie=true, azimut=90, times=15, alarme=false, h_ouvertur=450, temperature="Chambre"}
-- 6eme volet : nom du device volet 6 
les_volets[#les_volets+1] = {volet="Volet bureau", piece="principale", Type="somfy", presence=true, fenetre="Fenetre bureau", porte=false, pluie=true, azimut=270, times=10, alarme=true}

--------------------------------------------
----------- Fin variables à éditer ---------
--------------------------------------------

local nom_script = 'Gestion volets'
local version = '2.7'
local heures = 0
local minutes = 0
local secondes = 0
local sunrise = 0   -- lever du soleil
local sunset = 0    -- coucher du soleil
local now = 0
local min_volet_matin = min_volet_matin_hh*60 + min_volet_matin_mm
delai_on_off = delai_on_off*60

local variables_user = {}
variables_user[#variables_user+1] = "alerte_pluie"

--------------------------------------------
---------------- Fonctions -----------------
-------------------------------------------- 

---- fonction print log ---- 
function voir_les_logs (s, debugging) -- nécessite la variable local debugging
    if (debugging) then 
		if s ~= nil then
            print (s)
		else
		    print ("aucune valeur affichable")
		end
    end
end	
--------------------------------------------

---- fonction arrondi ----
function round(value, digits)
    local precision = 10^digits
    return (value >= 0) and
        (math.floor(value * precision + 0.5) / precision) or
        (math.ceil(value * precision - 0.5) / precision)
end
--------------------------------------------

---- retourne le temps en minutes depuis la dernière màj du périphérique ----
function TimeDiff(device)
    timestamp = otherdevices_lastupdate[device] or device
    y, m, d, H, M, S = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    difference = os.difftime(os.time(), os.time{year=y, month=m, day=d, hour=H, min=M, sec=S})
    return difference
end
--------------------------------------------

---- fonction min vers hh:mm ----
function min_to_hh_mm(mmm)
    hh = math.floor(mmm/(60))
    reste = (mmm%60)
    mm = math.floor(reste)
    if (hh<10) then hh='0'..hh..'' end
    if (mm<10) then mm='0'..mm..'' end
    return hh..":"..mm
end
--------------------------------------------

---- fonction selection ordre open/closed par type de volets ----
function ordre_type(type_volet, ordre, attente, types)
    if attente == nil then
        if ordre == "opening" then
            if type_volet == "somfy" then
                return 'Off'
            else
                return 'On'
            end
        elseif ordre == "closing" then
            if type_volet == "somfy" then
                return 'On'
            else
                return 'Off'
            end
        else
            return ordre
        end
    else
        if ordre == "opening" then
            if type_volet == "somfy" then
                return 'Off '..types..' '..tonumber(attente)..' SECONDS'
            else
                return 'On '..types..' '..tonumber(attente)..' SECONDS'
            end
        elseif ordre == "closing" then
            if type_volet == "somfy" then
                return 'On '..types..' '..tonumber(attente)..' SECONDS'
            else
                return 'Off '..types..' '..tonumber(attente)..' SECONDS'
            end
        else
            return ordre..' '..types..' '..tonumber(attente)..' SECONDS'
        end
    end
end
--------------------------------------------

---- fonction sleep ----
function sleep (a) 
    local sec = tonumber(os.clock() + a); 
    while (os.clock() < sec) do 
    end 
end

--------------------------------------------

------ encode la chaine str pour la passer dans une url 
function url_encode(str) 
   if (str) then
   str = string.gsub (str, "\n", "\r\n")
   str = string.gsub (str, "([^%w ])",
   function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   end
   return str
end

--------------------------------------------
-------------- Fin Fonctions ---------------
--------------------------------------------


---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------    DEBUT DU PROGRAME DE GESTION DES VOLETS    -------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
commandArray = {}

if (script_actif == true) then
    voir_les_logs("========= ".. nom_script .." (v".. version ..") =========",debugging)
    time=os.time()
    now = tonumber(os.date('%H')*60 + os.date('%M'))
    sunrise = tonumber(timeofday['SunriseInMinutes']) -- lever du soleil
    sunset = tonumber(timeofday['SunsetInMinutes']) -- coucher du soleil
    mode_volets = otherdevices[mode_volets]
    azimute_sun = tonumber(otherdevices[azimute_sun])
    elevation_sun = tonumber(otherdevices[elevation_sun])
    alerte_pluie = false 
    --= otherdevices_svalues['']
    for k,var_use in pairs(variables_user) do
        if(uservariables[var_use] == nil) then -- Création de la variable  car elle n'existe pas
            voir_les_logs("--- --- --- La Variable " .. var_use .." n'existe pas --- --- --- ",debugging)
            commandArray['OpenURL'] = url..'/json.htm?type=command&param=adduservariable&vname='..url_encode(var_use)..'&vtype=2&vvalue='
        end
    end
    timestamp = otherdevices_lastupdate['Security Panel'] or 'Security Panel'
    y, m, d, H, M, S = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    TimeDiffsecurity = os.difftime(os.time(), os.time{year=y, month=m, day=d, hour=H, min=M, sec=S})
    local minutes=tonumber(os.date('%M',time))
    local hours=tonumber(os.date('%H',time))
    local timeInMinutes = hours * 60 + minutes;
    if (minutes<10) then minutes='0'..minutes..'' end
    if (hours<10) then hours='0'..hours..'' end
    local time=''..hours..':'..minutes
    local temperature_exterieure = otherdevices_temperature[sonde_ext]
    voir_les_logs("--- --- --- Heure actuelle : "..time.."",debugging)
    voir_les_logs('--- --- --- Température extérieure : '..temperature_exterieure,debugging)
    voir_les_logs("--- --- --- Heure de levé du soleil : "..min_to_hh_mm(timeofday['SunriseInMinutes']),debugging);
    voir_les_logs("--- --- --- Heure de couché du soleil : "..min_to_hh_mm(timeofday['SunsetInMinutes']),debugging);
    voir_les_logs('--- --- --- delai entre 2 mouvements des volets : '..delai_on_off/60 ..' minute(s)',debugging) 
    voir_les_logs('--- --- --- Mode '..mode_volets..' de gestion des volets',debugging)
    for k,v in pairs(les_volets) do-- On parcourt chaque volet
        if(uservariables[v.volet] == nil) then -- Création de la variable  car elle n'existe pas
            voir_les_logs("--- --- --- La Variable " .. v.volet .." n'existe pas --- --- --- ",debugging)
            commandArray['OpenURL'] = url..'/json.htm?type=command&param=adduservariable&vname='..url_encode(v.volet)..'&vtype=2&vvalue='..tostring(os.date('%j')..' '..now)
        end
        voir_les_logs('--- --- ---',debugging);
        voir_les_logs('--- --- --- Gestion du volet : '..v.volet,debugging);
        voir_les_logs('--- --- --- Position du volet : '..otherdevices[v.volet],debugging)
        voir_les_logs('--- --- --- dernier mouvement du volet : '..round(TimeDiff(v.volet)/60 , 1) ..' minute(s)',debugging)
        
        ------------------------------------------------------
        -- OUVERTURE de tous les volets par COMMANDE manuel --
        ------------------------------------------------------
        if (option_cmd_manu == true and otherdevices[device_cmd_closed] == value_cmd_opened) then
            voir_les_logs("--- --- --- Commande manuel d'ouverture",debugging)
            if (mode_volets == "Canicule") then
                if (azimute_sun <= tonumber(v.azimut)-75 and azimute_sun >= tonumber(v.azimut)+65) then
                    if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' ) then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "opening")
                    end
                end
            else  
                 if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' ) then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                end
            end
        end
        
        ------------------------------------------------------
        -- FERMETURE de tous les volets par COMMANDE manuel --
        ------------------------------------------------------
        if (option_cmd_manu == true and otherdevices[device_cmd_closed] == value_cmd_closed) then
            voir_les_logs('--- --- --- Commande manuel de fermeture',debugging)
            if mode_volets == 'Canicule' then
                if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped') and (v.piece=="principale" or v.piece=="eau" or v.piece=="service") then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            else
                if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' ) then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            end
        end
        
        --------------------------------------------------------
        -- OUVERTURE des volets chambres COMMANDE automatique --
        --------------------------------------------------------
        if (now == v.h_ouvertur and (v.piece=="chambre")) then
            voir_les_logs("--- --- --- Commande automatique d'ouverture chambre",debugging)
            if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' ) then
                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                if option_stop == true then
                    if uservariables[v.volet] ~= tostring(os.date('%j')..' '..now) then
                        commandArray[#commandArray+1] = {['Variable:'..v.volet] = tostring(os.date('%j')..' '..now)}
                        commandArray[v.volet]=ordre_type(v.Type, "stop")
                    end
                else
                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                end
            end
        end
        if v.piece=="chambre" then
            if now == v.h_ouvertur+60 then
                voir_les_logs("--- --- --- Commande automatique d'ouverture chambre",debugging)
                if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' ) then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                end
            end
        end
        
        --------------------------------------------------------
        -- FERMETURE des volets chambres COMMANDE automatique --
        --------------------------------------------------------
        if v.piece=="chambre" then
            if (now == sunset-10 and otherdevices[v.fenetre]=="Closed") then
                voir_les_logs("--- --- --- Commande automatique de fermeture chambre",debugging)
                if (otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped') then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            end
            if (devicechanged[v.fenetre]) then
                if (now >= sunset or now <= sunrise-delai_avant_leve_soleil-10) and otherdevices[v.fenetre]=="Closed" then
                    voir_les_logs("--- --- --- Commande automatique de fermeture chambre",debugging)
                    if (otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped') then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "closing")
                    end
                elseif (now >= sunset or now <= sunrise-delai_avant_leve_soleil-10) and otherdevices[v.fenetre]=="Open" then
                    voir_les_logs("--- --- --- Commande automatique de fermeture chambre",debugging)
                    if (otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped') then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ferme ==> Ouverture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "opening")
                    end
                end
            end
            if (now > sunset or now < sunrise) and otherdevices_temperature[sonde_ext] <= 13.5 then
                voir_les_logs("--- --- --- Commande automatique de fermeture chambre",debugging)
                if (otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped') then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            end
        end 
        
        ------------------------------------------------------------
        -- FERMETURE VOLETS des chambres AVANT LE LEVER DU SOLEIL --
        ------------------------------------------------------------
        if (sunrise-delai_avant_leve_soleil == now and v.piece=="chambre") then
            voir_les_logs('--- --- --- Avant le levé du soleil',debugging)
            if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' )    and TimeDiff(v.volet) > delai_on_off then
                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                commandArray[v.volet]=ordre_type(v.Type, "closing")
            end
        end
            
        --------------------------------------------------------
        -- FERMETURE des volets COMMANDE automatique si PLUIE --
        --------------------------------------------------------
        if uservariables["alerte_pluie"] ~= otherdevices_rain_lasthour[device_pluie] then
            commandArray[#commandArray+1] = {['Variable:alerte_pluie'] = tostring(otherdevices_rain_lasthour[device_pluie])}
        end
        if (v.pluie == true and tonumber(otherdevices_rain_lasthour[device_pluie])>=0.3 and TimeDiff(uservariables["alerte_pluie"]) < 10*60) then
            if otherdevices[v.fenetre]=="Open" then
                alerte_pluie = true 
                voir_les_logs("--- --- --- Commande automatique de Fermeture car fenetre ouverte et pluie",debugging)
                if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' ) then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            elseif otherdevices[v.fenetre]=="Closed" and TimeDiff(v.fenetre) < 15 then
                voir_les_logs("--- --- --- Commande automatique de Ouveture car fenetere fermé mais pluie",debugging)
                if ( otherdevices[v.volet]=='Closed') then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                end
            end
        end
        
        ----------------------------------------------------------------
        ----------------- Commande OPTION ALARME ACTIVE ----------------
        ----------------------------------------------------------------
        if option_alarme==true then
            ------------------------------------------------------------
            -- FERMETURE des volets COMMANDE automatique ALARME Armed --
            ------------------------------------------------------------
            if (globalvariables['Security'] == 'Armed Away' and TimeDiffsecurity < 3 and v.presence == true) then
                voir_les_logs("--- --- --- Commande automatique de fermeture volet alarme "..v.volet ,debugging)
                if otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "closing")
                end
            end
        
            ---------------------------------------------------------------
            -- OUVERTURE des volets COMMANDE automatique ALARME Disarmed --
            ---------------------------------------------------------------
            if (globalvariables['Security'] == 'Disarmed' and TimeDiffsecurity < 3 and v.presence == true) then
                voir_les_logs("--- --- --- Commande automatique d'ouverture volet alarme"..v.volet ,debugging)
                if otherdevices[v.volet]=='Closed' then
                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                    voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                end
            end
        end
        
        if alerte_pluie == false then
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------
            ------------------------------- MODE NORMAL DES VOLETS -------------------------------
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------
            if mode_volets == "Normal" then
                
                ------------------------------------------------------------------------------------
                -- OUVERTURE VOLETS des pieces principales / eau / service AUX LE LEVER DU SOLEIL --
                ------------------------------------------------------------------------------------
                if (((sunrise <= min_volet_matin and now == min_volet_matin) or (sunrise == now and now >= min_volet_matin)) and (v.piece=="principale" or v.piece=="eau" or v.piece=="service")) then
                    voir_les_logs('--- --- --- Aux le levé du soleil',debugging)
                    if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        if (v.presence== false or v.presence == nil) then
                            voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                            voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                            commandArray[v.volet]=ordre_type(v.Type, "opening")
                        elseif (v.presence == true) then
                            if (otherdevices[device_presence] == value_presence) then
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                                commandArray[v.volet]=ordre_type(v.Type, "opening")
                            else
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet ne peux pas etre ouvert car pas de presence detecter',debugging)
                            end
                        end
                    end
                end
                
                ----------------------------------------------------------------------------------------
                -- FERMETURE VOLETS des pieces principales / eau / service APRES LE COUCHER DU SOLEIL --
                ----------------------------------------------------------------------------------------
                if ((sunset+delai_apres_couche_soleil) == timeInMinutes and (v.piece=="principale" or v.piece=="eau" or v.piece=="service") and v.porte==false) then
                    voir_les_logs('--- --- --- Après le coucher du soleil',debugging)
                    if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        if option_stop == true then
                            if uservariables[v.volet]~= tostring(os.date('%j')..' '..now) then
                                commandArray[#commandArray+1] = {['Variable:'..v.volet] = tostring(os.date('%j')..' '..now)}
                                commandArray[v.volet]=ordre_type(v.Type, "stop")
                            end
                        else
                            commandArray[v.volet]=ordre_type(v.Type, "closing")
                        end
                    end
                end
                
                ------------------------------------------------------------------------------------------------------
                -- FERMETURE complète de tous les volets APRES LE COUCHER DU SOLEIL et delais sus OU opt cmd closed --
                ------------------------------------------------------------------------------------------------------
                if ((sunset+delai_apres_couche_soleil+delai_closed_apres_couche_soleil) == now and v.porte==false) then
                    voir_les_logs('--- --- --- Après le coucher du soleil + delais suplementaire',debugging)
                    if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "closing")
                    end
                end
            
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------
            ------------------------------- MODE TARDIF DES VOLETS -------------------------------
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------
            elseif mode_volets == "Tardif" then
                
                ------------------------------------------------------------------------------------
                -- OUVERTURE VOLETS des pieces principales / eau / service AUX LE LEVER DU SOLEIL --
                ------------------------------------------------------------------------------------
                if (((sunrise <= min_volet_matin+delai_sus_tarif and now == min_volet_matin+delai_sus_tarif) or (sunrise == now and now >= min_volet_matin+delai_sus_tarif)) and (v.piece=="principale" or v.piece=="eau" or v.piece=="service")) then
                    voir_les_logs('--- --- --- Aux le levé du soleil',debugging)
                    if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        if (v.presence== false or v.presence == nil) then
                            voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                            voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                            commandArray[v.volet]=ordre_type(v.Type, "opening")
                        elseif (v.presence == true) then
                            if (otherdevices[device_presence] == value_presence) then
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                                commandArray[v.volet]=ordre_type(v.Type, "opening")
                            else
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet ne peux pas etre ouvert car pas de presence detecter',debugging)
                            end
                        end
                    end
                end
                
                ----------------------------------------------------------------------------------------
                -- FERMETURE VOLETS des pieces principales / eau / service APRES LE COUCHER DU SOLEIL --
                ----------------------------------------------------------------------------------------
                if ((sunset+delai_apres_couche_soleil+delai_sus_tarif) == now and (v.piece=="principale" or v.piece=="eau" or v.piece=="service") and v.porte==false) then
                    voir_les_logs('--- --- --- Après le coucher du soleil',debugging)
                    if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' ) and TimeDiff(v.volet) > delai_on_off then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        if option_stop == true then
                            if uservariables[v.volet]~= tostring(os.date('%j')..' '..now) then
                                commandArray[#commandArray+1] = {['Variable:'..v.volet] = tostring(os.date('%j')..' '..now)}
                                commandArray[v.volet]=ordre_type(v.Type, "stop")
                            end
                        else
                            commandArray[v.volet]=ordre_type(v.Type, "closing")
                        end
                    end
                end
                
                ------------------------------------------------------------------------------------
                -- FERMETURE complète de tous les volets APRES LE COUCHER DU SOLEIL et delais sus --
                ------------------------------------------------------------------------------------
                if ((sunset+delai_apres_couche_soleil+delai_closed_apres_couche_soleil+delai_sus_tarif) == now and v.porte==false) then
                    voir_les_logs('--- --- --- Après le coucher du soleil + delais suplementaire',debugging)
                    if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' ) and TimeDiff(v.volet) > delai_on_off then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "closing")
                    end
                end
            
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------
            ------------------------------ MODE CANICULE DES VOLETS ------------------------------
            --------------------------------------------------------------------------------------
            --------------------------------------------------------------------------------------  
            elseif mode_volets == "Canicule" then
                 
                --------------------------------------------------------------------------------------
                -- OUVERTURE VOLETS des pieces principales / eau / service AVANT LE LEVER DU SOLEIL --
                --------------------------------------------------------------------------------------
                if (now == sunrise-delai_avant_leve_soleil and (v.piece=="principale" or v.piece=="eau" or v.piece=="service")) then
                    voir_les_logs('--- --- --- Aux le levé du soleil',debugging)
                    if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        if v.presence == true then
                            if (otherdevices[device_presence] == value_presence) then
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                                commandArray[v.volet]=ordre_type(v.Type, "opening")
                            else
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet ne peux pas etre ouvert car pas de presence detecter',debugging)
                            end
                        else
                            voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être fermé',debugging)
                            voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                            commandArray[v.volet]=ordre_type(v.Type, "opening")
                        end
                    end
                end
                
                --------------------------------------------------------------------------
                -- ACTION VOLETS en fonction de l'orientation du soleil apres sont levé --
                --------------------------------------------------------------------------
                if (now > sunrise and v.azimut ~= nil) then
                    voir_les_logs('--- --- --- Ce volet bouge en fonction du soleil',debugging)
                    if (azimute_sun >= tonumber(v.azimut)-75 and azimute_sun <= tonumber(v.azimut)+65 and elevation_sun >= 10)then
                        voir_les_logs ('--- --- --- Commande Fermeture azimut soleil',debugging)
                        if (otherdevices[v.volet]=='Open' and TimeDiff(v.volet) > delai_on_off and v.execution ~= tostring(os.date('%j')..' '..now)) then
                            voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                            voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                            commandArray[v.volet]=ordre_type(v.Type, "closing", v.times, "FOR")
                            v.execution = tostring(os.date('%j')..' '..now)
                        end
                    elseif (elevation_sun >= 5 and now > min_volet_matin+tonumber(120)) then
                        if (v.presence == false or v.presence == nil) then
                            voir_les_logs ('--- --- --- Commande Ouverture azimut soleil',debugging)
                            if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                                voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être partielement fermé',debugging)
                                voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                                commandArray[v.volet]=ordre_type(v.Type, "opening")
                            end
                        elseif (v.presence == true) then
                            if otherdevices[device_presence]==value_presence then
                                voir_les_logs ('--- --- --- Commande Ouverture azimut soleil',debugging)
                                if ( otherdevices[v.volet]=='Closed' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                                    voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être partielement fermé',debugging)
                                    voir_les_logs ('--- --- --- Le volet est Fermé ==> Ouverture',debugging)
                                    commandArray[v.volet]=ordre_type(v.Type, "opening")
                                end
                            end
                        end
                    end
                end
                
                ------------------------------------------------------------------------------------------------------
                -- FERMETURE VOLETS des pieces principales / eau / service APRES LE COUCHER DU SOLEIL et delais sus --
                ------------------------------------------------------------------------------------------------------
                if (sunset+delai_apres_couche_soleil+delai_closed_apres_couche_soleil+delai_sus_tarif) > 1440 then 
                    time_closed = (sunset+delai_apres_couche_soleil+delai_closed_apres_couche_soleil+delai_sus_tarif)-1440 
                else 
                    time_closed = sunset+delai_apres_couche_soleil+delai_closed_apres_couche_soleil+delai_sus_tarif 
                end
                
                if (time_closed == now and (v.piece=="principale" or v.piece=="eau" or v.piece=="service")) then
                    voir_les_logs('--- --- --- Après le coucher du soleil + delais suplementaire',debugging)
                    if ( otherdevices[v.volet]=='Open' or otherdevices[v.volet]=='Stopped' )	and TimeDiff(v.volet) > delai_on_off then
                        voir_les_logs ('--- --- --- Le volet : "'..v.volet..'" doit être ouvert',debugging)
                        voir_les_logs ('--- --- --- Le volet est Ouvert ==> Fermeture',debugging)
                        commandArray[v.volet]=ordre_type(v.Type, "closing")
                    end
                end
            elseif (mode_volets == "manuel") then
            else
                voir_les_logs ('--- --- --- Mode gestion volet non reconnu',debugging)
            end
        end
    end
end
return commandArray
