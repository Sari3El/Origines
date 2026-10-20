--[[-----------------------------------------------------------------------
	Origine du monde — mise à terre et captures (client)

	À terre : écran assombri et désaturé, « Vous êtes à terre » et le temps
	restant. Les autres voient « À terre » / « Ligoté » au-dessus de la tête.
	E sur un joueur à terre ou ligoté : petit menu d'actions.
-------------------------------------------------------------------------]]

local M = ORIGINE.MiseATerre
local CM = ORIGINE.ConfigMiseATerre
local UI = ORIGINE.UI
local COL = UI.C

UI.DefinirPolice("mat_grand", 34, 700, true)
UI.DefinirPolice("mat_tete", 17, 700, true)

local function temps(s)
	s = math.max(0, math.ceil(s))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------------
-- Écran du joueur à terre
---------------------------------------------------------------------------
local COULEURS = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = -0.12, ["$pp_colour_contrast"] = 0.85, ["$pp_colour_colour"] = 0.15,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "origine_mise_a_terre", function()
	if ORIGINE.EstATerre(LocalPlayer()) then DrawColorModify(COULEURS) end
end)

local cVoile = Color(0, 0, 0, 120)

hook.Add("HUDPaint", "origine_mise_a_terre", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local w, h = ScrW(), ScrH()

	-- Inventaire fermé à terre ou ligoté
	if ORIGINE.EstImmobilise(ply) and ORIGINE.Inv and IsValid(ORIGINE.Inv.Fenetre) then ORIGINE.Inv.Fenetre:Close() end

	if ORIGINE.EstATerre(ply) then
		UI.Rect(0, h * 0.36, w, UI.S(96), cVoile)
		UI.TexteOmbre("Vous êtes à terre", "mat_grand", w / 2, h * 0.36 + UI.S(30), COL.Alerte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local reste = ply:GetNW2Float("origine_terre_fin", 0) - CurTime()
		UI.TexteOmbre("Temps restant : " .. temps(reste), "texte_gras", w / 2, h * 0.36 + UI.S(70), COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif ORIGINE.EstLigote(ply) then
		local e = M.Escorteur(ply)
		UI.TexteOmbre(e and "Ligoté — escorté par " .. ORIGINE.NomComplet(e) or "Vous êtes ligoté", "texte_gras",
			w / 2, h - UI.S(160), COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Barre de progression d'une action (relever, ligoter, délier)
	local p = M.Progression
	if p then
		local f = math.Clamp((CurTime() - p.debut) / p.duree, 0, 1)
		if f >= 1 then M.Progression = nil return end
		local bw, bh = UI.S(320), UI.S(12)
		local x, y = w / 2 - bw / 2, h * 0.62
		UI.TexteOmbre(p.texte, "texte_gras", w / 2, y - UI.S(14), COL.Texte, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		UI.Rect(x - 1, y - 1, bw + 2, bh + 2, COL.Bordure)
		UI.Rect(x, y, bw, bh, Color(8, 6, 5, 235))
		UI.Rect(x, y, bw * f, bh, COL.Or)
	end
end)

net.Receive("origine_mat_progression", function()
	local duree, texte = net.ReadFloat(), net.ReadString()
	M.Progression = duree > 0 and { debut = CurTime(), duree = duree, texte = texte } or nil
end)

---------------------------------------------------------------------------
-- « À terre » / « Ligoté » au-dessus de la tête (tout le monde)
---------------------------------------------------------------------------
local visibles, prochain = {}, 0
local decalage = Vector(0, 0, 20)

hook.Add("HUDPaint", "origine_mise_a_terre_tetes", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if CurTime() >= prochain then
		prochain = CurTime() + 0.25
		visibles = {}
		local oeil = ply:EyePos()
		for _, p in ipairs(player.GetAll()) do
			if p ~= ply and p:Alive() and ORIGINE.EstImmobilise(p) and oeil:Distance(p:GetPos()) < CM.DistanceAffichage then
				visibles[#visibles + 1] = p
			end
		end
	end
	for _, p in ipairs(visibles) do
		if IsValid(p) then
			local base = ORIGINE.EstATerre(p) and p:GetPos() or p:EyePos()
			local ecran = (base + decalage):ToScreen()
			if ecran.visible then
				local aTerre = ORIGINE.EstATerre(p)
				UI.TexteOmbre(aTerre and "À terre" or "Ligoté", "mat_tete", ecran.x, ecran.y,
					aTerre and COL.Alerte or COL.Or, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Touche E sur un joueur à terre ou ligoté : menu d'actions
---------------------------------------------------------------------------
local function envoyer(cible, action)
	net.Start("origine_mat_action")
		net.WriteEntity(cible)
		net.WriteString(action)
	net.SendToServer()
end

local function cibleVisee(ply)
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector() * CM.Distance,
		filter = ply,
		mask = MASK_SHOT,
	})
	local e = tr.Entity
	if IsValid(e) and e:IsPlayer() and ORIGINE.EstImmobilise(e) then return e end
	-- Un joueur au sol est bas : on cherche aussi autour du point visé
	for _, p in ipairs(ents.FindInSphere(tr.HitPos, 40)) do
		if p:IsPlayer() and p ~= ply and ORIGINE.EstImmobilise(p) then return p end
	end
	return nil
end

hook.Add("PlayerBindPress", "origine_mise_a_terre", function(ply, bind, presse)
	if not presse or not string.find(bind, "+use", 1, true) then return end
	if ORIGINE.EstImmobilise(ply) or vgui.CursorVisible() then return end
	local cible = cibleVisee(ply)
	if not cible then return end

	local m = DermaMenu()
	local nom = ORIGINE.NomComplet(cible)
	if ORIGINE.EstATerre(cible) then
		m:AddOption("Relever " .. nom, function() envoyer(cible, "relever") end):SetIcon("icon16/heart.png")
		m:AddOption("Ligoter " .. nom, function() envoyer(cible, "ligoter") end):SetIcon("icon16/link.png")
	else
		m:AddOption("Délier " .. nom, function() envoyer(cible, "delier") end):SetIcon("icon16/link_break.png")
		if cible:GetNW2Entity("origine_ravisseur") == ply then
			if M.Escorteur(cible) == ply then
				m:AddOption("Lâcher", function() envoyer(cible, "lacher") end):SetIcon("icon16/door_out.png")
			else
				m:AddOption("Escorter", function() envoyer(cible, "escorter") end):SetIcon("icon16/user_go.png")
			end
		end
	end
	m:Open()
	m:Center()
	return true
end)
