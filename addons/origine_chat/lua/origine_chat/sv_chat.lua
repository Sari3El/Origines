--[[-----------------------------------------------------------------------
	Origine du monde — chat (serveur) : anti-spam
	Les règles du menu personnage (seul l'OOC est autorisé) restent gérées
	par origine_personnages.
-------------------------------------------------------------------------]]

local CC = ORIGINE.ConfigChat

local function exempte(ply)
	return ORIGINE.DansListe(CC.AntiSpam.GroupesExemptes, ply:GetUserGroup())
end

hook.Add("PlayerSay", "origine_chat_antispam", function(ply, texte)
	if not IsValid(ply) or exempte(ply) then return end
	local maintenant = CurTime()
	local a = CC.AntiSpam
	ply.OrigineChat = ply.OrigineChat or { envois = {}, textes = {} }
	local etat = ply.OrigineChat

	-- Nombre de messages dans la fenêtre
	for i = #etat.envois, 1, -1 do
		if maintenant - etat.envois[i] > a.Fenetre then table.remove(etat.envois, i) end
	end
	if #etat.envois >= a.Messages then
		ORIGINE.Notifier(ply, "Doucement : vous écrivez trop vite.", "erreur")
		return ""
	end

	-- Même message répété
	local cle = ORIGINE.Normaliser(string.Trim(texte))
	local repetitions = 0
	for i = #etat.textes, 1, -1 do
		local t = etat.textes[i]
		if maintenant - t.date > a.FenetreRepetition then
			table.remove(etat.textes, i)
		elseif t.cle == cle then
			repetitions = repetitions + 1
		end
	end
	if repetitions >= a.Repetitions then
		ORIGINE.Notifier(ply, "Vous avez déjà envoyé ce message plusieurs fois.", "erreur")
		return ""
	end

	etat.envois[#etat.envois + 1] = maintenant
	etat.textes[#etat.textes + 1] = { cle = cle, date = maintenant }
end)
