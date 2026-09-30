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

---------------------------------------------------------------------------
-- /roll : 1d100 par défaut, /roll XdY sinon (MaxDes dés au plus)
---------------------------------------------------------------------------
util.AddNetworkString("origine_chat_des")

function ORIGINE.LancerDes(ply, nombre, faces)
	local D = CC.Des
	local resultats, total = {}, 0
	for i = 1, nombre do
		local r = math.random(1, faces)
		resultats[i] = r
		total = total + r
	end
	local texte = ORIGINE.NomComplet(ply) .. " lance " .. nombre .. "d" .. faces .. " : "
	if nombre == 1 then
		texte = texte .. total
	else
		texte = texte .. table.concat(resultats, ", ") .. " (total " .. total .. ")"
	end
	local cibles = {}
	for _, p in ipairs(player.GetAll()) do
		if D.Portee <= 0 or p == ply or p:GetPos():Distance(ply:GetPos()) <= D.Portee then cibles[#cibles + 1] = p end
	end
	net.Start("origine_chat_des")
		net.WriteString(texte)
	net.Send(cibles)
	hook.Run("origine_LancerDes", ply, nombre, faces, resultats, total)
end

hook.Add("PlayerSay", "origine_chat_des", function(ply, texte)
	local t = string.lower(string.Trim(texte))
	if t ~= "/roll" and t ~= "!roll" and not t:find("^[/!]roll%s") then return end
	if ORIGINE.EnMenu(ply) then return "" end
	local arg = string.Trim(t:sub(6))
	local nombre, faces = 1, 100
	if arg ~= "" then
		local n, f = arg:match("^(%d*)d(%d+)$")
		if not f then
			ORIGINE.Notifier(ply, "Utilisation : /roll ou /roll 3d20", "erreur")
			return ""
		end
		nombre, faces = tonumber(n ~= "" and n or "1"), tonumber(f)
	end
	if nombre < 1 or nombre > CC.Des.MaxDes then
		ORIGINE.Notifier(ply, "Entre 1 et " .. CC.Des.MaxDes .. " dés.", "erreur")
		return ""
	end
	if faces < 2 or faces > CC.Des.MaxFaces then
		ORIGINE.Notifier(ply, "Un dé a entre 2 et " .. CC.Des.MaxFaces .. " faces.", "erreur")
		return ""
	end
	ORIGINE.LancerDes(ply, nombre, faces)
	return ""
end)
