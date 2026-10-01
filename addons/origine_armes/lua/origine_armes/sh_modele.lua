--[[-----------------------------------------------------------------------
	Origine du monde — modèle d'épée des armes wOS (partagé)

	wOS fait partir la lame invisible (les touches) :
	  - du point d'attache « blade1 » du modèle s'il en a un (modèle préparé
	    pour wOS : rien à faire) ;
	  - sinon de la main du joueur, dans l'axe où l'on tient un manche de sabre
	    (SWEP:GetSaberPosAng).
	Un modèle d'épée simple (sans « blade1 » ni os de main) n'est pas placé
	correctement par wOS. Ce fichier le place ALIGNÉ SUR CETTE LAME : la lame
	du modèle (son côté le plus long, pointe = le bout le plus loin de l'origine
	du modèle) suit exactement la ligne des touches, et sa garde est mise au
	départ de cette ligne. L'épée visible et la zone de touche coïncident donc,
	quelle que soit la posture.
	Réglages : SWEP.OrigineEnMain (en jeu : origine_epee_placer, origine_epee_debug 1).
	L'épée rangée (lame « éteinte », touche R) et l'épée portée à la ceinture (arme
	possédée mais pas en main) sont placées au fourreau, à la ceinture (A.Ceinture),
	au lieu du placement de wOS prévu pour un petit manche de sabre.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Armes = ORIGINE.Armes or {}
local A = ORIGINE.Armes

local OS_MAIN = "ValveBiped.Bip01_R_Hand"

-- Réglages par défaut (chaque arme peut avoir son SWEP.OrigineEnMain)
A.EnMainDefaut = {
	Garde = 0.2,    -- position de la garde sur la longueur du modèle (0 = pommeau, 1 = pointe)
	Avance = 0,     -- décalage le long de la lame (unités ; négatif = l'épée recule dans la main)
	Roulis = 0,     -- rotation autour de la lame (degrés : tranchant vers l'avant, à plat...)
	Echelle = 1,
}
-- Épée à la ceinture : à gauche de la taille, pointe vers le bas et l'arrière
A.Ceinture = {
	Active = true,
	Cote = 8,           -- vers la gauche (unités)
	Avant = 2,          -- vers l'avant
	Haut = 2,           -- vers le haut
	Inclinaison = 35,   -- angle de la lame avec la verticale, vers l'arrière (degrés)
	Roulis = 90,
	Ecart = 6,          -- décalage entre deux épées portées
}

---------------------------------------------------------------------------
-- Axe de la lame d'un modèle, d'après ses dimensions
---------------------------------------------------------------------------
-- mins / maxs : boîte du modèle. Renvoie { axe = 1|2|3 (x, y, z), signe = 1|-1, longueur,
-- pommeau = coordonnée du bout côté poignée }. La lame est le côté le plus long ; la pointe est
-- le bout le plus éloigné de l'origine du modèle (l'origine est en général vers la poignée).
function A.AxeDuModele(mins, maxs)
	local mn, mx = { mins.x, mins.y, mins.z }, { maxs.x, maxs.y, maxs.z }
	local dims = { mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3] }
	local axe = 1
	for i = 2, 3 do if dims[i] > dims[axe] then axe = i end end
	local signe = (mx[axe] >= -mn[axe]) and 1 or -1
	return { axe = axe, signe = signe, longueur = dims[axe], pommeau = signe > 0 and mn[axe] or mx[axe] }
end

-- Angle local qui couche l'axe (axe, signe) du modèle sur l'axe X d'un repère
local ANGLES_AXE = {
	[1] = { [1] = Angle(0, 0, 0), [-1] = Angle(0, 180, 0) },
	[2] = { [1] = Angle(0, -90, 0), [-1] = Angle(0, 90, 0) },
	[3] = { [1] = Angle(90, 0, 0), [-1] = Angle(-90, 0, 0) },
}

local function axeDe(ent)
	local mdl = ent:GetModel()
	if ent.OrigineAxeModele ~= mdl then
		ent.OrigineAxeModele = mdl
		local mn, mx = ent:GetModelBounds()
		ent.OrigineAxe = (mn and mx) and A.AxeDuModele(mn, mx) or nil
	end
	return ent.OrigineAxe
end

-- Place un modèle pour que sa lame suive la direction dir et que sa garde soit en depart.
-- Renvoie position et angle du modèle.
function A.AlignerSurLame(ent, depart, dir, cfg)
	local info = axeDe(ent)
	if not info then return nil end
	cfg = cfg or A.EnMainDefaut
	local echelle = tonumber(cfg.Echelle) or 1
	local repere = dir:Angle()
	repere:RotateAroundAxis(dir, tonumber(cfg.Roulis) or 0)
	local _, angModele = LocalToWorld(vector_origin, ANGLES_AXE[info.axe][info.signe], vector_origin, repere)
	-- Point de la garde dans le modèle, ramené au départ de la lame
	local garde = info.pommeau + info.signe * (tonumber(cfg.Garde) or 0.2) * info.longueur
	local g = garde * echelle
	local pointGarde = Vector(info.axe == 1 and g or 0, info.axe == 2 and g or 0, info.axe == 3 and g or 0)
	local decal = LocalToWorld(pointGarde, angle_zero, vector_origin, angModele)
	local pos = depart - decal + dir * (tonumber(cfg.Avance) or 0)
	return pos, angModele
end

-- Le modèle a-t-il ce qu'il faut pour que wOS le place seul ? (point « blade1 » ou os de la main)
function A.ModeleWOS(w)
	local mdl = w:GetModel()
	if w.OrigineModeleTeste ~= mdl then
		w.OrigineModeleTeste = mdl
		w.OrigineModeleWOS = (w:LookupAttachment("blade1") or 0) > 0 or w:LookupBone(OS_MAIN) ~= nil
	end
	return w.OrigineModeleWOS
end

---------------------------------------------------------------------------
-- Appelé par A.Preparer pour chaque arme
---------------------------------------------------------------------------
function A.PreparerModele(SWEP)
	if isstring(SWEP.UseHilt) and SWEP.UseHilt ~= "" then
		SWEP.WorldModel = SWEP.UseHilt
		if util and util.PrecacheModel then util.PrecacheModel(SWEP.UseHilt) end
	end
end

if not CLIENT then return end

local function echelleModele(ent, e)
	if e ~= 1 then
		local mat = Matrix()
		mat:Scale(Vector(e, e, e))
		ent:EnableMatrix("RenderMultiply", mat)
	else
		ent:DisableMatrix("RenderMultiply")
	end
end

---------------------------------------------------------------------------
-- Épée en main : placée juste avant que wOS la dessine (rendu translucide : les os du
-- joueur sont prêts). Les fonctions de dessin de wOS ne sont pas remplacées.
---------------------------------------------------------------------------
local placees = setmetatable({}, { __mode = "k" })

-- Place de la n-ième épée à la ceinture (0 = la première) : départ de la lame et direction.
-- Accrochée à l'os du bassin et orientée comme le corps (pas comme le regard : le haut du corps
-- tourne quand on regarde autour de soi, pas le bassin).
function A.PositionCeinture(ply, n)
	local C = A.Ceinture
	local idOs = ply:LookupBone("ValveBiped.Bip01_Pelvis")
	if not idOs then return nil end
	local hanche = ply:GetBonePosition(idOs)
	if not hanche then return nil end
	local corps = Angle(0, (ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles()).y, 0)
	local inc = math.rad(C.Inclinaison)
	local dir = LocalToWorld(Vector(-math.sin(inc), 0, -math.cos(inc)), angle_zero, vector_origin, corps)
	local depart = hanche + LocalToWorld(Vector(C.Avant - (n or 0) * C.Ecart, C.Cote, C.Haut), angle_zero, vector_origin, corps)
	return depart, dir
end

-- L'arme en main est-elle rangée (lame « éteinte » de wOS, touche R) ?
function A.EpeeRangee(w)
	return w.GetEnabled ~= nil and not w:GetEnabled()
end

function A.PlacerEnMain(w)
	if not w.GetSaberPosAng or A.ModeleWOS(w) then return false end
	local cfg = w.OrigineEnMain or A.EnMainDefaut
	local pos, ang
	if A.EpeeRangee(w) and A.Ceinture.Active then
		-- Épée rangée : au fourreau, à la ceinture
		local depart, dir = A.PositionCeinture(w:GetOwner(), 0)
		if not depart then return false end
		pos, ang = A.AlignerSurLame(w, depart, dir, { Garde = cfg.Garde, Avance = 0, Roulis = A.Ceinture.Roulis, Echelle = cfg.Echelle })
	else
		local ok, depart, dir = pcall(w.GetSaberPosAng, w)
		if not (ok and depart and dir) then return false end
		pos, ang = A.AlignerSurLame(w, depart, dir, cfg)
	end
	if not pos then return false end
	w:SetRenderOrigin(pos)
	w:SetRenderAngles(ang)
	echelleModele(w, tonumber(cfg.Echelle) or 1)
	placees[w] = true
	return true
end

hook.Add("PreDrawTranslucentRenderables", "origine_epee_main", function(_, ciel)
	if ciel then return end
	for _, p in ipairs(player.GetAll()) do
		local w = p:GetActiveWeapon()
		if IsValid(w) and A.EstArme and A.EstArme(w) then A.PlacerEnMain(w) end
	end
end)

-- Arme lâchée ou rangée : position normale
hook.Add("Think", "origine_epee_main", function()
	for w in pairs(placees) do
		if not IsValid(w) then
			placees[w] = nil
		elseif not IsValid(w:GetOwner()) or w:GetOwner():GetActiveWeapon() ~= w then
			w:SetRenderOrigin()
			w:SetRenderAngles()
			w:DisableMatrix("RenderMultiply")
			placees[w] = nil
		end
	end
end)

---------------------------------------------------------------------------
-- Épée à la ceinture
---------------------------------------------------------------------------
local fourreaux = {} -- [joueur][classe] = modèle client

local function modeleCeinture(ply, classe, mdl)
	fourreaux[ply] = fourreaux[ply] or {}
	local m = fourreaux[ply][classe]
	if not IsValid(m) then
		m = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
		if not IsValid(m) then return nil end
		m:SetNoDraw(true)
		fourreaux[ply][classe] = m
	end
	if m:GetModel() ~= mdl then m:SetModel(mdl) end
	return m
end

hook.Add("PostPlayerDraw", "origine_epee_ceinture", function(ply)
	local C = A.Ceinture
	if not C.Active or not GetGlobalBool("rb655_lightsaber_hiltonbelt", false) then return end
	if wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.StopDrawOnBelt then return end
	if ply:GetNW2Float("CloakTime", 0) >= CurTime() then return end
	local actif = ply:GetActiveWeapon()
	-- L'arme en main rangée occupe déjà la première place
	local n = (IsValid(actif) and A.EstArme(actif) and A.EpeeRangee(actif)) and 1 or 0
	for classe in pairs(A.Classes) do
		local w = ply:GetWeapon(classe)
		if IsValid(w) and w ~= actif and isstring(w.WorldModel) and w.WorldModel ~= "" then
			local m = modeleCeinture(ply, classe, w.WorldModel)
			if m then
				local depart, dir = A.PositionCeinture(ply, n)
				local cfg = w.OrigineEnMain or A.EnMainDefaut
				local pos, ang
				if depart then pos, ang = A.AlignerSurLame(m, depart, dir, { Garde = cfg.Garde, Avance = 0, Roulis = C.Roulis, Echelle = cfg.Echelle }) end
				if pos then
					m:SetPos(pos)
					m:SetAngles(ang)
					echelleModele(m, tonumber(cfg.Echelle) or 1)
					m:SetupBones()
					m:DrawModel()
					n = n + 1
				end
			end
		end
	end
end)

hook.Add("EntityRemoved", "origine_epee_ceinture", function(ent)
	local t = fourreaux[ent]
	if not t then return end
	for _, m in pairs(t) do if IsValid(m) then m:Remove() end end
	fourreaux[ent] = nil
end)

-- La ceinture de wOS (prévue pour un manche de sabre) ne dessine plus les armes Origine
function A.RemplacerCeintureWOS()
	local t = hook.GetTable().PostPlayerDraw
	local avant = t and t["wOS.Lightsaber.HolsterDrawing"]
	if not avant or avant == A.CeintureWOS then return end
	A.CeintureWOS = function(ply, ...)
		local general = wOS and wOS.Lightsabers and wOS.Lightsabers.General
		if not istable(general) then return avant(ply, ...) end
		local retires = {}
		for classe in pairs(A.Classes) do
			if general[classe] ~= nil then retires[classe] = general[classe] general[classe] = nil end
		end
		local ok, err = pcall(avant, ply, ...)
		for classe, v in pairs(retires) do general[classe] = v end
		if not ok then ErrorNoHalt(err .. "\n") end
	end
	hook.Add("PostPlayerDraw", "wOS.Lightsaber.HolsterDrawing", A.CeintureWOS)
end
hook.Add("InitPostEntity", "origine_epee_ceinture", A.RemplacerCeintureWOS)
hook.Add("wOS.ALCS.OnLoaded", "origine_epee_ceinture", A.RemplacerCeintureWOS)

---------------------------------------------------------------------------
-- Réglage en jeu
---------------------------------------------------------------------------
local debug = CreateClientConVar("origine_epee_debug", "0", false, false,
	"1 = dessine la zone de touche des armes Origine (réglage du modèle d'épée)")

-- origine_epee_placer garde avance roulis [échelle] : règle l'épée en main (aperçu local)
concommand.Add("origine_epee_placer", function(ply, _, args)
	local w = IsValid(ply) and ply:GetActiveWeapon()
	if not (IsValid(w) and A.EstArme and A.EstArme(w)) then
		print("[Origine] Prenez une arme Origine en main.")
		return
	end
	local cfg = table.Copy(w.OrigineEnMain or A.EnMainDefaut)
	if #args >= 1 then
		local n = {}
		for i = 1, 4 do n[i] = tonumber(args[i]) end
		cfg.Garde = n[1] or cfg.Garde
		cfg.Avance = n[2] or cfg.Avance
		cfg.Roulis = n[3] or cfg.Roulis
		cfg.Echelle = n[4] or cfg.Echelle
		w.OrigineEnMain = cfg
		local stockee = weapons.GetStored(w:GetClass())
		if stockee then stockee.OrigineEnMain = cfg end
	end
	if A.ModeleWOS(w) then
		print("[Origine] Ce modèle est préparé pour wOS (blade1 ou os de main) : wOS le place lui-même.")
	end
	print("[Origine] À mettre dans les fichiers d'arme (lua/weapons/weapon_origine_*.lua) :")
	print(string.format("SWEP.OrigineEnMain = { Garde = %s, Avance = %s, Roulis = %s, Echelle = %s }",
		tostring(cfg.Garde), tostring(cfg.Avance), tostring(cfg.Roulis), tostring(cfg.Echelle)))
	local info = axeDe(w)
	if info then
		local lame = math.Round((1 - (tonumber(cfg.Garde) or 0.2)) * info.longueur * (tonumber(cfg.Echelle) or 1) + (tonumber(cfg.Avance) or 0))
		print(string.format("[Origine] Longueur du modèle : %d unités. Lame visible ≈ %d : SWEP.UseLength = %d",
			math.Round(info.longueur), lame, lame))
	end
end, nil, "Règle l'épée Origine en main : garde (0-1) avance roulis [échelle]")

-- Zone de touche : ligne rouge de la longueur SWEP.UseLength, depuis le départ de la lame
hook.Add("PostDrawTranslucentRenderables", "origine_epee_debug", function(_, ciel)
	if ciel or not debug:GetBool() then return end
	for _, p in ipairs(player.GetAll()) do
		local w = p:GetActiveWeapon()
		if IsValid(w) and A.EstArme and A.EstArme(w) and w.GetSaberPosAng then
			local ok, pos, dir = pcall(w.GetSaberPosAng, w)
			if ok and pos and dir then
				local long = tonumber(w.UseLength) or 42
				render.DrawLine(pos, pos + dir * long, Color(255, 60, 60), false)
				render.DrawWireframeSphere(pos, 1, 6, 6, Color(255, 220, 60), false)
			end
		end
	end
end)
