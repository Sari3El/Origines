--[[-----------------------------------------------------------------------
	Origine du monde — modèle d'épée des armes wOS (partagé)

	wOS dessine le modèle de l'arme (SWEP.UseHilt / SWEP.WorldModel) dans la
	main du joueur et fait partir la lame (invisible : les touches) :
	  - du point d'attache « blade1 » du modèle s'il en a un (modèle préparé
	    pour wOS : tout est déjà juste) ;
	  - sinon de la main du joueur, dans l'axe d'un manche de sabre tenu.
	Un modèle préparé comme une arme (os ValveBiped.Bip01_R_Hand) se colle
	tout seul à la main. Un modèle d'objet simple (sans cet os) apparaîtrait
	aux pieds du joueur : ce fichier le place alors dans la main avec
	SWEP.OrigineEnMain (réglable en jeu avec origine_epee_placer).
	Option : SWEP.OrigineLame = { Debut = Vector(), Axe = Vector() } fait partir
	les touches de la vraie lame du modèle (coordonnées du modèle).
	Aide au réglage : origine_epee_debug 1 dessine la zone de touche.
-------------------------------------------------------------------------]]

ORIGINE = ORIGINE or {}
ORIGINE.Armes = ORIGINE.Armes or {}
local A = ORIGINE.Armes

local OS_MAIN = "ValveBiped.Bip01_R_Hand"

-- Le modèle de l'arme a-t-il l'os de la main (préparé comme une arme) ? Mis en cache par modèle.
function A.ModeleArme(w)
	local mdl = w:GetModel()
	if w.OrigineModeleTeste ~= mdl then
		w.OrigineModeleTeste = mdl
		w.OrigineModeleArme = w:LookupBone(OS_MAIN) ~= nil
		w.OrigineModeleBlade = (w:LookupAttachment("blade1") or 0) > 0
	end
	return w.OrigineModeleArme, w.OrigineModeleBlade
end

-- Position et angle de l'épée dans la main (nil si le joueur n'a pas de main utilisable).
-- Modèle préparé comme une arme : la main elle-même. Sinon : la main + SWEP.OrigineEnMain.
function A.PositionEnMain(w)
	local own = w:GetOwner()
	if not IsValid(own) then return nil end
	local idOs = own:LookupBone(OS_MAIN)
	if not idOs then return nil end
	local m = own:GetBoneMatrix(idOs)
	if not m then return nil end
	local pos, ang = m:GetTranslation(), m:GetAngles()
	if A.ModeleArme(w) then return pos, ang end
	local cfg = w.OrigineEnMain or {}
	return LocalToWorld(cfg.Pos or vector_origin, cfg.Ang or angle_zero, pos, ang)
end

-- Fonction de la base wOS (cherchée au moment de l'appel)
local function deLaBase(w, nom)
	local b = baseclass.Get(w.Base)
	if b and b[nom] then return b[nom] end
	return w.BaseClass and w.BaseClass[nom]
end

---------------------------------------------------------------------------
-- Appelé par A.Preparer pour chaque arme
---------------------------------------------------------------------------
function A.PreparerModele(SWEP)
	if isstring(SWEP.UseHilt) and SWEP.UseHilt ~= "" then
		SWEP.WorldModel = SWEP.UseHilt
		if util and util.PrecacheModel then util.PrecacheModel(SWEP.UseHilt) end
	end

	-- Touches le long de la vraie lame du modèle (facultatif)
	if istable(SWEP.OrigineLame) then
		function SWEP:GetSaberPosAng(num, side, model, ...)
			local lame = self.OrigineLame
			if lame and not side and (model == nil or model == self) then
				local _, blade = A.ModeleArme(self)
				if not blade then
					local pos, ang = A.PositionEnMain(self)
					if pos then
						local debut = LocalToWorld(lame.Debut or vector_origin, angle_zero, pos, ang)
						local bout = LocalToWorld(lame.Axe or Vector(0, 0, 1), angle_zero, pos, ang)
						return debut, (bout - pos):GetNormalized()
					end
				end
			end
			local f = deLaBase(self, "GetSaberPosAng")
			if f then return f(self, num, side, model, ...) end
		end
	end

end

---------------------------------------------------------------------------
-- Client : modèle d'objet simple placé dans la main, juste avant que wOS le dessine
-- (wOS dessine le modèle pendant le rendu translucide ; les os du joueur sont alors prêts).
-- Les fonctions de dessin de wOS ne sont pas remplacées.
---------------------------------------------------------------------------
if CLIENT then
	local placees = setmetatable({}, { __mode = "k" })

	hook.Add("PreDrawTranslucentRenderables", "origine_epee_main", function(_, ciel)
		if ciel then return end
		for _, p in ipairs(player.GetAll()) do
			local w = p:GetActiveWeapon()
			if IsValid(w) and A.EstArme and A.EstArme(w) and not A.ModeleArme(w) then
				local pos, ang = A.PositionEnMain(w)
				if pos then
					w:SetRenderOrigin(pos)
					w:SetRenderAngles(ang)
					placees[w] = true
					local e = w.OrigineEnMain and tonumber(w.OrigineEnMain.Echelle) or 1
					if e ~= 1 then
						local mat = Matrix()
						mat:Scale(Vector(e, e, e))
						w:EnableMatrix("RenderMultiply", mat)
					else
						w:DisableMatrix("RenderMultiply")
					end
				end
			end
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
end

---------------------------------------------------------------------------
-- Client : réglage en jeu
---------------------------------------------------------------------------
if CLIENT then
	local debug = CreateClientConVar("origine_epee_debug", "0", false, false,
		"1 = dessine la zone de touche des armes Origine (réglage du modèle d'épée)")

	local function format(v) return string.format("%.2f, %.2f, %.2f", v[1], v[2], v[3]) end

	-- origine_epee_placer x y z pitch yaw roll [échelle] : place l'épée dans la main (aperçu local)
	concommand.Add("origine_epee_placer", function(ply, _, args)
		local w = IsValid(ply) and ply:GetActiveWeapon()
		if not (IsValid(w) and A.EstArme and A.EstArme(w)) then
			print("[Origine] Prenez une arme Origine en main.")
			return
		end
		local cfg = w.OrigineEnMain or {}
		if #args >= 6 then
			local n = {}
			for i = 1, 7 do n[i] = tonumber(args[i]) end
			for i = 1, 6 do if not n[i] then print("[Origine] Nombres attendus : x y z pitch yaw roll [échelle]") return end end
			cfg = { Pos = Vector(n[1], n[2], n[3]), Ang = Angle(n[4], n[5], n[6]), Echelle = n[7] or cfg.Echelle or 1 }
			w.OrigineEnMain = cfg
			local stockee = weapons.GetStored(w:GetClass())
			if stockee then stockee.OrigineEnMain = cfg end
		end
		local arme = A.ModeleArme(w)
		if arme then
			print("[Origine] Ce modèle est préparé comme une arme : il se place tout seul, OrigineEnMain n'est pas utilisé.")
		end
		print("[Origine] À mettre dans le fichier de l'arme (lua/weapons/" .. w:GetClass() .. ".lua) :")
		print(string.format("SWEP.OrigineEnMain = { Pos = Vector( %s ), Ang = Angle( %s ), Echelle = %s }",
			format(cfg.Pos or vector_origin), format(cfg.Ang or angle_zero), tostring(cfg.Echelle or 1)))
	end, nil, "Place l'épée Origine dans la main : x y z pitch yaw roll [échelle]")

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
end
