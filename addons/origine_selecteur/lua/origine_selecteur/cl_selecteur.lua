--[[-----------------------------------------------------------------------
	Origine du monde — sélecteur d'armes (client)

	Rien n'est dessiné quand il est fermé. Le suivi des cooldowns tourne en
	permanence, mais seulement sur les armes du joueur : à l'ouverture, les
	barres sont déjà à jour.
-------------------------------------------------------------------------]]

local CS = ORIGINE.ConfigSelecteur
ORIGINE.Selecteur = ORIGINE.Selecteur or {}
local SEL = ORIGINE.Selecteur
SEL.Cooldowns = SEL.Cooldowns or {}   -- [arme] = { primaire = {fin, duree, vu}, secondaire = {…} }

---------------------------------------------------------------------------
-- Charte
---------------------------------------------------------------------------
local function COL()
	return (ORIGINE.UI and ORIGINE.UI.C) or CS.CouleursParDefaut
end

local function S(v)
	return math.max(1, math.Round(v * math.Clamp(ScrH() / 1080, 0.62, 2.2)))
end

local function creerPolices()
	local charte = ORIGINE.Config and ORIGINE.Config.Charte
	local titre = charte and charte.PoliceTitre or CS.PolicesParDefaut.Titre
	local txt = charte and charte.PoliceTexte or CS.PolicesParDefaut.Texte
	surface.CreateFont("origine_sel_numero", { font = titre, size = S(20), weight = 700, antialias = true, extended = true })
	surface.CreateFont("origine_sel_nom", { font = txt, size = S(16), weight = 700, antialias = true, extended = true })
	surface.CreateFont("origine_sel_petit", { font = txt, size = S(13), weight = 500, antialias = true, extended = true })
	surface.CreateFont("origine_sel_hl2", { font = "HalfLife2", size = S(46), weight = 0, antialias = true, additive = true })
end
creerPolices()
hook.Add("OnScreenSizeChanged", "origine_selecteur", creerPolices)

---------------------------------------------------------------------------
-- Sons
---------------------------------------------------------------------------
local function son(id)
	local cfg = CS.Sons
	if not cfg.Actives then return end
	local f = cfg.Fichiers[id]
	local ply = LocalPlayer()
	if f and f ~= "" and IsValid(ply) then ply:EmitSound(f, 0, 100, cfg.Volume, CHAN_STATIC) end
end

---------------------------------------------------------------------------
-- Suivi des cooldowns (NextPrimaryFire / NextSecondaryFire, ou SWEP:OrigineCooldowns)
---------------------------------------------------------------------------
local function suivre(etat, cle, fin, maintenant, dureeImposee)
	local e = etat[cle]
	if dureeImposee then
		-- Le SWEP donne lui-même sa durée
		if fin > maintenant and dureeImposee >= CS.SeuilCooldown then
			etat[cle] = { fin = fin, duree = dureeImposee, vu = fin }
		else
			etat[cle] = nil
		end
		return
	end
	if e and e.vu == fin then return end
	-- Nouveau cooldown : durée totale mesurée à son démarrage
	local duree = fin - maintenant
	if duree >= CS.SeuilCooldown then
		etat[cle] = { fin = fin, duree = duree, vu = fin }
	else
		etat[cle] = { vu = fin }   -- trop court : jamais affiché
	end
end

hook.Add("Tick", "origine_selecteur_cooldowns", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local maintenant = CurTime()
	local vus = {}
	for _, w in ipairs(ply:GetWeapons()) do
		vus[w] = true
		local etat = SEL.Cooldowns[w]
		if not etat then
			etat = {}
			SEL.Cooldowns[w] = etat
			-- Première vue : on retient la valeur actuelle sans créer de barre
			etat.primaire = { vu = w:GetNextPrimaryFire() }
			etat.secondaire = { vu = w:GetNextSecondaryFire() }
		end
		local donnees = w.OrigineCooldowns and w:OrigineCooldowns()
		if istable(donnees) then
			local p, s = donnees.primaire, donnees.secondaire
			suivre(etat, "primaire", p and tonumber(p.fin) or 0, maintenant, p and tonumber(p.duree) or 0)
			suivre(etat, "secondaire", s and tonumber(s.fin) or 0, maintenant, s and tonumber(s.duree) or 0)
		else
			suivre(etat, "primaire", w:GetNextPrimaryFire(), maintenant)
			suivre(etat, "secondaire", w:GetNextSecondaryFire(), maintenant)
		end
	end
	for w in pairs(SEL.Cooldowns) do
		if not vus[w] then SEL.Cooldowns[w] = nil end
	end
end)

-- Cooldowns en cours d'une arme : liste { {frac, restant, couleur}, … } (clic gauche d'abord)
local function cooldownsActifs(w)
	local etat = SEL.Cooldowns[w]
	if not etat then return {} end
	local maintenant = CurTime()
	local liste = {}
	for _, cle in ipairs({ "primaire", "secondaire" }) do
		local e = etat[cle]
		if e and e.fin and e.fin > maintenant then
			local restant = e.fin - maintenant
			liste[#liste + 1] = {
				frac = math.Clamp(restant / e.duree, 0, 1),
				restant = restant,
				couleur = cle == "primaire" and CS.CouleurPrimaire or CS.CouleurSecondaire,
			}
		end
	end
	return liste
end

---------------------------------------------------------------------------
-- Icônes
---------------------------------------------------------------------------
local ICONE_DEFAUT = surface.GetTextureID("weapons/swep")
local BASE

local function aIcone(w)
	if not w:IsScripted() then return CS.IconesHL2[w:GetClass()] ~= nil end
	BASE = BASE or weapons.GetStored("weapon_base")
	if w.DrawWeaponSelection and BASE and w.DrawWeaponSelection ~= BASE.DrawWeaponSelection then return true end
	return w.WepSelectIcon ~= nil and w.WepSelectIcon ~= ICONE_DEFAUT
end

local function dessinerIcone(w, x, y, lw, lh, alpha)
	if not w:IsScripted() then
		local lettre = CS.IconesHL2[w:GetClass()]
		local c = COL().Or
		draw.SimpleText(lettre, "origine_sel_hl2", x + lw / 2, y + lh / 2, Color(c.r, c.g, c.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end
	BASE = BASE or weapons.GetStored("weapon_base")
	if w.DrawWeaponSelection and BASE and w.DrawWeaponSelection ~= BASE.DrawWeaponSelection then
		-- Dessin propre au SWEP ; une erreur dans son code ne casse pas le sélecteur
		local ok, err = pcall(w.DrawWeaponSelection, w, x, y, lw, lh, alpha)
		if not ok then ErrorNoHalt("[Origine] DrawWeaponSelection de " .. w:GetClass() .. " : " .. tostring(err) .. "\n") end
		return
	end
	-- Icône carrée centrée, sans déformation
	local cote = math.min(lw, lh * 2)
	surface.SetTexture(w.WepSelectIcon)
	surface.SetDrawColor(255, 255, 255, alpha)
	surface.DrawTexturedRect(x + (lw - cote) / 2, y + (lh - cote / 2) / 2, cote, cote / 2)
end

---------------------------------------------------------------------------
-- Rareté des SWEPs de race (config de origine_personnages)
---------------------------------------------------------------------------
local cacheRarete = {}
local function couleurRarete(classe)
	if cacheRarete[classe] ~= nil then return cacheRarete[classe] or nil end
	local col = false
	local C = ORIGINE.Config
	if C and C.Races and ORIGINE.RareteDeRace then
		for _, race in ipairs(C.Races) do
			for _, s in ipairs(race.Mod and race.Mod.Sweps or {}) do
				if s == classe then
					local r = ORIGINE.RareteDeRace(race.id)
					col = r and r.Couleur or false
				end
			end
			if col then break end
		end
	end
	cacheRarete[classe] = col
	return col or nil
end

---------------------------------------------------------------------------
-- Colonnes : une par slot, armes triées par SlotPos, Sacoche en tête du slot 1
---------------------------------------------------------------------------
local function colonnes()
	local ply = LocalPlayer()
	local cols = {}
	for i = 1, CS.Colonnes do cols[i] = {} end
	local premieres = {}
	for i, classe in ipairs(CS.PremieresDuSlot1) do premieres[classe] = i end

	for _, w in ipairs(ply:GetWeapons()) do
		if IsValid(w) then
			local c = premieres[w:GetClass()] and 1 or math.Clamp(w:GetSlot() + 1, 1, CS.Colonnes)
			table.insert(cols[c], w)
		end
	end
	for _, liste in ipairs(cols) do
		table.sort(liste, function(a, b)
			local pa, pb = premieres[a:GetClass()], premieres[b:GetClass()]
			if pa or pb then
				if pa and pb then return pa < pb end
				return pa ~= nil
			end
			if a:GetSlotPos() ~= b:GetSlotPos() then return a:GetSlotPos() < b:GetSlotPos() end
			return a:GetClass() < b:GetClass()
		end)
	end
	return cols
end

-- Toutes les armes dans l'ordre d'affichage (pour la molette)
local function aplatir(cols)
	local liste = {}
	for _, c in ipairs(cols) do
		for _, w in ipairs(c) do liste[#liste + 1] = w end
	end
	return liste
end

---------------------------------------------------------------------------
-- Ouverture / fermeture
---------------------------------------------------------------------------
local function peutOuvrir()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return false end
	if ply:InVehicle() and not ply:GetAllowWeaponsInVehicle() then return false end
	if ORIGINE.MenuOuvert and ORIGINE.MenuOuvert() then return false end
	if ORIGINE.EnMenu and ORIGINE.EnMenu(ply) then return false end
	if ORIGINE.TabOuvert and ORIGINE.TabOuvert() then return false end
	-- À terre ou ligoté (origine_mise_a_terre)
	if ORIGINE.EstImmobilise and ORIGINE.EstImmobilise(ply) then return false end
	-- Inventaire, sac, menu staff ou toute autre fenêtre avec curseur
	if vgui.CursorVisible() then return false end
	return true
end

function SEL.Fermer()
	SEL.Ouvert = false
	SEL.Arme = nil
end

local function toucher()
	SEL.Ouvert = true
	SEL.DerniereAction = RealTime()
end

local function equiper(w)
	if not IsValid(w) then return end
	if w ~= LocalPlayer():GetActiveWeapon() then input.SelectWeapon(w) end
	son("Selection")
end

-- Molette : arme suivante (+1) ou précédente (-1)
local function defiler(sens)
	local liste = aplatir(colonnes())
	if #liste == 0 then return end
	local courante = SEL.Ouvert and SEL.Arme or LocalPlayer():GetActiveWeapon()
	local idx = 0
	for i, w in ipairs(liste) do if w == courante then idx = i break end end
	if idx == 0 then idx = sens > 0 and 0 or 1 end
	local suivante = liste[(idx - 1 + sens) % #liste + 1]
	if GetConVar("hud_fastswitch"):GetBool() then
		equiper(suivante)
		return
	end
	SEL.Arme = suivante
	toucher()
	son("Defilement")
end

-- Touches 1 à 6 : ouvre le slot, un nouvel appui passe à l'arme suivante du slot
local function choisirSlot(n)
	local cols = colonnes()
	local liste = cols[n]
	if not liste or #liste == 0 then
		if not GetConVar("hud_fastswitch"):GetBool() then
			SEL.Arme = nil
			SEL.SlotVide = n
			toucher()
			son("Defilement")
		end
		return
	end
	-- Premier appui : première arme du slot ; appuis suivants : arme suivante
	-- (en fastswitch, « suivante » part de l'arme en main)
	local rapide = GetConVar("hud_fastswitch"):GetBool()
	local courante = SEL.Ouvert and SEL.Arme or (rapide and LocalPlayer():GetActiveWeapon()) or nil
	local idx = 0
	for i, w in ipairs(liste) do if w == courante then idx = i break end end
	local suivante = liste[idx % #liste + 1]
	if rapide then
		equiper(suivante)
		return
	end
	SEL.Arme = suivante
	SEL.SlotVide = nil
	toucher()
	son("Defilement")
end

hook.Add("HUDShouldDraw", "origine_selecteur", function(nom)
	if nom == "CHudWeaponSelection" then return false end
end)

hook.Add("PlayerBindPress", "origine_selecteur", function(ply, bind, presse)
	if not presse then return end
	bind = string.lower(bind)

	if SEL.Ouvert then
		if string.find(bind, "+attack2", 1, true) then
			SEL.Fermer()
			return true
		end
		if string.find(bind, "+attack", 1, true) then
			local w = SEL.Arme
			SEL.Fermer()
			equiper(w)
			return true
		end
		if bind == "cancelselect" then
			SEL.Fermer()
			return true
		end
	end

	local molette = bind == "invnext" and 1 or bind == "invprev" and -1 or nil
	local slot = tonumber(string.match(bind, "^slot(%d)$"))
	if not molette and not (slot and slot >= 1 and slot <= CS.Colonnes) then return end

	-- Physgun : la molette sert à rapprocher/éloigner l'objet tenu
	if molette then
		local actif = ply:GetActiveWeapon()
		if IsValid(actif) and actif:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK) then return end
	end
	if not peutOuvrir() then
		SEL.Fermer()
		return
	end

	if molette then defiler(molette) else choisirSlot(slot) end
	return true
end)

---------------------------------------------------------------------------
-- Dessin (rien quand le sélecteur est fermé)
---------------------------------------------------------------------------
local function hauteurCarte(w)
	local h = S(30)
	if aIcone(w) then h = h + S(CS.HauteurIcone) end
	local n = #cooldownsActifs(w)
	if n > 0 then h = h + S(4) + n * S(n > 1 and 6 or 8) + S(16) end
	return h
end

-- Texte coupé avec « … » s'il dépasse la largeur
local function ajuster(t, police, largeur)
	surface.SetFont(police)
	if surface.GetTextSize(t) <= largeur then return t end
	local n = utf8.len(t) or #t
	while n > 1 do
		n = n - 1
		local fin = utf8.offset(t, n + 1)
		local essai = (fin and string.sub(t, 1, fin - 1) or t) .. "…"
		if surface.GetTextSize(essai) <= largeur then return essai end
	end
	return "…"
end

local function dessinerCarte(w, x, y, lw, lh, choisie)
	local c = COL()
	local rarete = couleurRarete(w:GetClass())
	surface.SetDrawColor(choisie and c.Survol or c.FondClair)
	surface.DrawRect(x, y, lw, lh)
	local cadre = choisie and c.Or or rarete or c.Bordure
	surface.SetDrawColor(cadre)
	surface.DrawOutlinedRect(x, y, lw, lh, choisie and S(3) or S(1))
	if choisie and rarete then
		surface.SetDrawColor(rarete)
		surface.DrawOutlinedRect(x + S(3), y + S(3), lw - S(6), lh - S(6), 1)
	end

	local cy = y + S(4)
	if aIcone(w) then
		dessinerIcone(w, x + S(6), cy, lw - S(12), S(CS.HauteurIcone) - S(4), choisie and 255 or 190)
		cy = cy + S(CS.HauteurIcone)
	end

	-- Nom et munitions
	local ply = LocalPlayer()
	local typeMun = w:GetPrimaryAmmoType()
	local munitions
	if typeMun and typeMun >= 0 then
		local reserve = ply:GetAmmoCount(typeMun)
		munitions = w:Clip1() >= 0 and (w:Clip1() .. " / " .. reserve) or tostring(reserve)
	end
	local largeurMun = 0
	if munitions then
		surface.SetFont("origine_sel_petit")
		largeurMun = surface.GetTextSize(munitions) + S(6)
	end
	local nom = ajuster(language.GetPhrase(w:GetPrintName() or w:GetClass()), "origine_sel_nom", lw - S(16) - largeurMun)
	draw.SimpleText(nom, "origine_sel_nom", x + S(8), cy + S(12), choisie and c.Texte or c.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if munitions then
		draw.SimpleText(munitions, "origine_sel_petit", x + lw - S(8), cy + S(12), c.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	cy = cy + S(26)

	-- Cooldowns : barre qui se vide + secondes restantes (clic gauche au-dessus)
	local cds = cooldownsActifs(w)
	if #cds > 0 then
		local epaisseur = S(#cds > 1 and 4 or 6)
		local restantMax = 0
		for i, cd in ipairs(cds) do
			local by = cy + (i - 1) * (epaisseur + S(2))
			surface.SetDrawColor(0, 0, 0, 160)
			surface.DrawRect(x + S(8), by, lw - S(16), epaisseur)
			surface.SetDrawColor(cd.couleur)
			surface.DrawRect(x + S(8), by, math.floor((lw - S(16)) * cd.frac), epaisseur)
			restantMax = math.max(restantMax, cd.restant)
		end
		local lignes = {}
		for _, cd in ipairs(cds) do
			lignes[#lignes + 1] = cd.restant >= 10 and string.format("%d s", math.ceil(cd.restant)) or string.format("%.1f s", cd.restant)
		end
		draw.SimpleText(table.concat(lignes, "  ·  "), "origine_sel_petit", x + lw / 2,
			cy + #cds * (epaisseur + S(2)) + S(6), c.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

hook.Add("HUDPaint", "origine_selecteur", function()
	if not SEL.Ouvert then return end
	if not peutOuvrir() or RealTime() - (SEL.DerniereAction or 0) > CS.FermetureAuto then
		SEL.Fermer()
		return
	end
	if SEL.Arme and not IsValid(SEL.Arme) then SEL.Arme = nil end

	local c = COL()
	local cols = colonnes()
	local lw, ecart = S(CS.LargeurCarte), S(8)
	local total = CS.Colonnes * lw + (CS.Colonnes - 1) * ecart
	local x0, y0 = math.floor(ScrW() / 2 - total / 2), S(CS.Marge)
	local tn = S(28)

	for i, liste in ipairs(cols) do
		local x = x0 + (i - 1) * (lw + ecart)
		-- Numéro du slot
		local actif = (SEL.Arme and table.HasValue(liste, SEL.Arme)) or SEL.SlotVide == i
		surface.SetDrawColor(c.Fond)
		surface.DrawRect(x, y0, lw, tn)
		surface.SetDrawColor(actif and c.Or or c.Bordure)
		surface.DrawOutlinedRect(x, y0, lw, tn, actif and S(2) or 1)
		draw.SimpleText(tostring(i), "origine_sel_numero", x + lw / 2, y0 + tn / 2, actif and c.Or or c.TexteSombre, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local y = y0 + tn + S(4)
		for _, w in ipairs(liste) do
			local h = hauteurCarte(w)
			dessinerCarte(w, x, y, lw, h, w == SEL.Arme)
			y = y + h + S(4)
		end
	end
end)
