--[[-----------------------------------------------------------------------
	Origine du monde — chat (client)

	Remplace la chatbox de GMod avec la charte commune. Les messages sont
	envoyés avec « say » : les commandes DarkRP et ULX fonctionnent comme avant.
	  - heure de chaque message [HH:MM:SS]
	  - flèches haut / bas : messages déjà envoyés
	  - un seul chat général (hors RP : /ooc ou // message)
	  - Tab : complète une commande ou un nom de joueur
	  - suggestions de commandes en tapant « / » ou « ! »
	  - nom de votre personnage surligné (et son) quand on vous cite
	  - clic droit sur un message : copier, répondre en MP, ignorer, ouvrir un lien
-------------------------------------------------------------------------]]

local UI = ORIGINE.UI
local COL = UI.C
local CC = ORIGINE.ConfigChat

ORIGINE.Chat = ORIGINE.Chat or {}
local CT = ORIGINE.Chat
CT.Messages = CT.Messages or {}
CT.Historique = CT.Historique or {}
CT.Defilement = 0
CT.IndexHist = 0

UI.DefinirPolice("chat", CC.TaillePolice, 500)
UI.DefinirPolice("chat_petit", 14, 600)

---------------------------------------------------------------------------
-- Préférences locales (cookies) et joueurs ignorés
---------------------------------------------------------------------------
local FICHIER_IGNORES = "origine_chat_ignores.json"
CT.Ignores = util.JSONToTable(file.Read(FICHIER_IGNORES, "DATA") or "") or {}

local function sauverIgnores()
	file.Write(FICHIER_IGNORES, util.TableToJSON(CT.Ignores))
end

local function pref(nom, defaut)
	return cookie.GetNumber("origine_chat_" .. nom, defaut and 1 or 0) == 1
end
local function reglerPref(nom, valeur)
	cookie.Set("origine_chat_" .. nom, valeur and "1" or "0")
end

local function horodatage() return CC.Horodatage and pref("horodatage", true) end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
local function estOOC(texte)
	for _, motif in ipairs(CC.MotifsOOC) do
		if string.find(texte, motif) then return true end
	end
	return false
end

local function texteBrut(morceaux)
	local t = {}
	for i, m in ipairs(morceaux) do t[i] = m[1] end
	return table.concat(t)
end

local function estMention(msg)
	local ply = LocalPlayer()
	if not IsValid(ply) or msg.auteur == ply or not IsValid(msg.auteur) then return false end
	local prenom = ORIGINE.Prenom(ply)
	if #prenom < 3 then return false end
	return string.find(ORIGINE.Normaliser(msg.contenu or ""), ORIGINE.Normaliser(prenom), 1, true) ~= nil
end

function CT.Ajouter(morceaux, canal, auteur, contenu)
	local sid = IsValid(auteur) and auteur:IsPlayer() and auteur:SteamID64() or nil
	if sid and CT.Ignores[sid] then return end
	local msg = {
		heure = os.time(), cree = CurTime(), morceaux = morceaux, canal = canal,
		auteur = auteur, sid = sid, brut = texteBrut(morceaux), contenu = contenu,
	}
	msg.mention = estMention(msg)
	if msg.mention and CC.SonMention ~= "" and pref("son", true) then surface.PlaySound(CC.SonMention) end

	table.insert(CT.Messages, msg)
	while #CT.Messages > CC.MessagesEnMemoire do table.remove(CT.Messages, 1) end

	if CT.Defilement > 0 and CT.LargeurTotale then
		-- La vue reste où elle est quand on lit plus haut
		local _, _, zw = CT.Zone()
		CT.Defilement = CT.Defilement + #CT.Decouper(msg, zw)
		CT.NouveauxEnBas = true
	end
	hook.Run("origine_ChatMessage", msg)
end

-- Arguments de chat.AddText -> morceaux { texte, couleur }
local function morceauxDepuisArgs(...)
	local morceaux, couleur = {}, COL.Texte
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if istable(v) and v.r and v.g and v.b then
			couleur = Color(v.r, v.g, v.b, 255)
		elseif isentity(v) then
			if IsValid(v) and v:IsPlayer() then
				morceaux[#morceaux + 1] = { ORIGINE.NomComplet(v), team.GetColor(v:Team()) }
			else
				morceaux[#morceaux + 1] = { "Console", COL.TexteSombre }
			end
		elseif v ~= nil then
			morceaux[#morceaux + 1] = { tostring(v), couleur }
		end
	end
	return morceaux
end

-- Tout ce qui passe par chat.AddText (annonces, addons, DarkRP sans joueur)
local enCapture = false
local function capturer(...)
	if enCapture then return end
	enCapture = true
	local ok, morceaux = pcall(morceauxDepuisArgs, ...)
	if ok and #morceaux > 0 then
		local brut = texteBrut(morceaux)
		CT.Ajouter(morceaux, estOOC(brut) and "ooc" or "systeme", nil, brut)
	end
	enCapture = false
end

if not CT.AddTextEnveloppe then
	CT.AddTextEnveloppe = true
	local ancien = chat.AddText
	chat.AddText = function(...)
		capturer(...)
		local deja = enCapture
		enCapture = true
		local r = ancien(...)
		enCapture = deja
		return r
	end
end

local function envelopperNonParse()
	if not chat.AddNonParsedText or CT.NonParseEnveloppe then return end
	CT.NonParseEnveloppe = true
	local ancien = chat.AddNonParsedText
	chat.AddNonParsedText = function(...)
		capturer(...)
		local deja = enCapture
		enCapture = true
		local r = ancien(...)
		enCapture = deja
		return r
	end
end

-- Messages des joueurs (GMod et DarkRP : DarkRP passe préfixe et couleurs en plus)
hook.Add("OnPlayerChat", "origine_chat", function(ply, texte, equipe, mort, prefixe, col1, texteDarkRP, col2)
	local morceaux, canal, contenu
	if isstring(prefixe) and isstring(texteDarkRP) then
		morceaux = {
			{ prefixe, IsColor(col1) and col1 or (IsValid(ply) and team.GetColor(ply:Team())) or COL.Texte },
			{ ": " .. texteDarkRP, IsColor(col2) and col2 or COL.Texte },
		}
		canal = estOOC(prefixe) and "ooc" or "rp"
		contenu = texteDarkRP
	else
		morceaux = {}
		if mort then morceaux[#morceaux + 1] = { "*MORT* ", COL.Alerte } end
		if equipe then morceaux[#morceaux + 1] = { "(Équipe) ", COL.Succes } end
		morceaux[#morceaux + 1] = { IsValid(ply) and ORIGINE.NomComplet(ply) or "Console",
			IsValid(ply) and team.GetColor(ply:Team()) or COL.TexteSombre }
		morceaux[#morceaux + 1] = { ": " .. tostring(texte), COL.Texte }
		canal = estOOC(tostring(texte)) and "ooc" or "rp"
		contenu = tostring(texte)
	end
	CT.Ajouter(morceaux, canal, ply, contenu)
	return true
end)

-- Messages du moteur (connexions, serveur…)
hook.Add("ChatText", "origine_chat", function(_, _, texte, typ)
	if typ == "chat" then return end
	CT.Ajouter({ { texte, COL.TexteSombre } }, "systeme", nil, texte)
	return true
end)

hook.Add("HUDShouldDraw", "origine_chat", function(nom)
	if nom == "CHudChat" then return false end
end)

---------------------------------------------------------------------------
-- Découpage des messages en lignes (mis en cache par largeur)
---------------------------------------------------------------------------
local function couperMot(mot, largeur)
	local codes = ORIGINE.Utf8Codes(mot) or {}
	local morceaux, courant = {}, ""
	for _, cp in ipairs(codes) do
		local c = ORIGINE.Utf8Char(cp)
		if surface.GetTextSize(courant .. c) > largeur and courant ~= "" then
			morceaux[#morceaux + 1] = courant
			courant = c
		else
			courant = courant .. c
		end
	end
	if courant ~= "" then morceaux[#morceaux + 1] = courant end
	return morceaux
end

local function decouper(msg, largeur)
	local cle = largeur .. "|" .. UI.Echelle() .. "|" .. tostring(horodatage())
	if msg.lignes and msg.cleLignes == cle then return msg.lignes end
	surface.SetFont(UI.Police("chat"))
	local lignes, ligne, x = {}, {}, 0
	local function pousser()
		lignes[#lignes + 1] = ligne
		ligne, x = {}, 0
	end
	local function ajouter(texte, col)
		local tw = surface.GetTextSize(texte)
		if x + tw > largeur and x > 0 then
			pousser()
			texte = texte:gsub("^%s+", "")
			tw = surface.GetTextSize(texte)
		end
		if tw > largeur then
			for i, bout in ipairs(couperMot(texte, largeur)) do
				if i > 1 then pousser() end
				ligne[#ligne + 1] = { bout, col, x }
				x = x + surface.GetTextSize(bout)
			end
			return
		end
		ligne[#ligne + 1] = { texte, col, x }
		x = x + tw
	end
	if horodatage() then ajouter(os.date("[%H:%M:%S] ", msg.heure), COL.TexteSombre) end
	for _, m in ipairs(msg.morceaux) do
		for mot in string.gmatch(m[1], "%s*[^%s]+%s*") do ajouter(mot, m[2]) end
	end
	if #ligne > 0 then pousser() end
	msg.lignes, msg.cleLignes = lignes, cle
	return lignes
end

CT.Decouper = decouper

local function totalLignes(largeur)
	local n = 0
	for _, msg in ipairs(CT.Messages) do
		n = n + #decouper(msg, largeur)
	end
	return n
end

-- Lignes visibles, de bas en haut (tableaux réutilisés : pas d'allocation par image)
local visL, visM, nVis = {}, {}, 0
local function remplirVisibles(largeur, nbMax, ferme)
	nVis = 0
	local saut = ferme and 0 or CT.Defilement
	local maintenant = CurTime()
	for i = #CT.Messages, 1, -1 do
		local msg = CT.Messages[i]
		if ferme and maintenant - msg.cree >= CC.DureeAffichage then break end
		local lignes = decouper(msg, largeur)
		for j = #lignes, 1, -1 do
			if saut > 0 then
				saut = saut - 1
			else
				nVis = nVis + 1
				visL[nVis], visM[nVis] = lignes[j], msg
				if nVis >= nbMax then return end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Commandes et complétion
---------------------------------------------------------------------------
local commandes
local function listeCommandes()
	if commandes then return commandes end
	commandes = {}
	local vues = {}
	local function ajouter(cmd, desc)
		cmd = string.lower(cmd)
		if vues[cmd] then return end
		vues[cmd] = true
		commandes[#commandes + 1] = { cmd, desc or "" }
	end
	for _, c in ipairs(CC.Commandes) do ajouter(c[1], c[2]) end
	if DarkRP and DarkRP.getChatCommands then
		local ok, liste = pcall(DarkRP.getChatCommands)
		if ok and istable(liste) then
			for nom, c in pairs(liste) do
				if isstring(nom) then ajouter("/" .. nom, istable(c) and isstring(c.description) and c.description or "") end
			end
		end
	end
	table.sort(commandes, function(a, b) return a[1] < b[1] end)
	return commandes
end

local function majSuggestions(texte)
	CT.Suggestions = nil
	if not texte:find("^[/!]") or texte:find("%s") then return end
	local bas = string.lower(texte)
	local res = {}
	for _, c in ipairs(listeCommandes()) do
		if string.sub(c[1], 1, #bas) == bas then
			res[#res + 1] = c
			if #res >= 6 then break end
		end
	end
	if #res > 0 then CT.Suggestions = res end
end

-- Complète le dernier mot avec un nom de joueur (Tab répété : nom suivant)
local completion
local function completerNom(entree)
	local texte = entree:GetText()
	if completion and completion.resultat == texte then
		completion.index = completion.index % #completion.liste + 1
	else
		local debut, mot = texte:match("^(.-)(%S*)$")
		if mot == "" then return end
		local cle = ORIGINE.Normaliser(mot)
		local liste = {}
		for _, p in ipairs(player.GetAll()) do
			for _, nom in ipairs({ ORIGINE.NomComplet(p), p:Nick() }) do
				if string.sub(ORIGINE.Normaliser(nom), 1, #cle) == cle and not table.HasValue(liste, nom) then
					liste[#liste + 1] = nom
				end
			end
		end
		if #liste == 0 then return end
		table.sort(liste)
		completion = { debut = debut, liste = liste, index = 1 }
	end
	completion.resultat = completion.debut .. completion.liste[completion.index] .. " "
	entree:SetText(completion.resultat)
	entree:SetCaretPos(#completion.resultat)
end

---------------------------------------------------------------------------
-- Panneau
---------------------------------------------------------------------------
local couleurMention = Color(255, 255, 255, 40)
local couleurOmbre = Color(0, 0, 0, 200)
local couleurZone = Color(12, 9, 7, 170)
local couleurSaisie = Color(16, 12, 9, 235)

local function tailles()
	local S = UI.S
	local w = S(CC.Largeur)
	local hOnglets, hEntree = S(22), S(34)
	local hMessages = S(CC.Hauteur)
	local h = hOnglets + hMessages + hEntree + S(16)
	local hud = (ORIGINE.HUD and ORIGINE.HUD.Hauteur and ORIGINE.HUD.Hauteur() or 0)
	local margeHud = ORIGINE.ConfigHUD and UI.S(ORIGINE.ConfigHUD.Marge) or 0
	local x = S(CC.MargeGauche)
	local y = ScrH() - S(8) - hud - margeHud - h
	return x, math.max(S(8), y), w, h, hOnglets, hMessages, hEntree
end

function CT.Construire()
	if IsValid(CT.Panneau) then CT.Panneau:Remove() end
	local pan = vgui.Create("EditablePanel")
	CT.Panneau = pan

	local barre = vgui.Create("DPanel", pan)
	CT.Barre = barre
	barre.Paint = function(_, bw, bh)
		UI.Texte("Chat", "chat_petit", UI.S(4), bh / 2, COL.Or, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		-- Compteur de caractères (hors du champ de saisie, pour ne rien chevaucher)
		local n = IsValid(CT.Entree) and #CT.Entree:GetText() or 0
		UI.Texte(n .. " / " .. CC.LongueurMax, "chat_petit", bw - bh - UI.S(8), bh / 2,
			n >= CC.LongueurMax and COL.Alerte or COL.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	local reglages = vgui.Create("DButton", barre)
	reglages:SetText("")
	reglages.Paint = function(s, bw, bh)
		-- Icône « menu » : trois barres
		local col = s:IsHovered() and COL.Or or COL.TexteSombre
		local lw, e = math.floor(bw * 0.5), math.max(1, UI.S(2))
		for i = -1, 1 do UI.Rect(bw / 2 - lw / 2, bh / 2 + i * UI.S(5) - e / 2, lw, e, col) end
	end
	reglages.DoClick = function() CT.MenuReglages() end
	CT.Reglages = reglages

	local entree = vgui.Create("DTextEntry", pan)
	entree:SetFont(UI.Police("chat"))
	entree:SetPaintBackground(false)
	entree:SetHistoryEnabled(false)
	entree.Paint = function(s, ew, eh)
		UI.Rect(0, 0, ew, eh, couleurSaisie)
		UI.Contour(0, 0, ew, eh, COL.Or, 1)
		if s:GetText() == "" then
			local aide = CT.Equipe and "Message d'équipe…" or "Écrire un message…  (hors RP : /ooc ou //)"
			UI.Texte(aide, "chat_petit", UI.S(6), eh / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		s:DrawTextEntryText(COL.Texte, COL.Or, COL.Texte)
	end
	entree.OnChange = function(s)
		local texte = s:GetText()
		if #texte > CC.LongueurMax then
			-- Coupe sans casser un caractère accentué
			local codes, res = ORIGINE.Utf8Codes(texte) or {}, ""
			for _, cp in ipairs(codes) do
				local c = ORIGINE.Utf8Char(cp)
				if #res + #c > CC.LongueurMax then break end
				res = res .. c
			end
			s:SetText(res)
			s:SetCaretPos(#res)
			texte = res
		end
		majSuggestions(texte)
		hook.Run("ChatTextChanged", texte)
	end
	entree.OnKeyCodeTyped = function(s, code)
		if code == KEY_ENTER or code == KEY_PAD_ENTER then
			CT.Envoyer()
			return true
		elseif code == KEY_UP then
			CT.Naviguer(1)
			return true
		elseif code == KEY_DOWN then
			CT.Naviguer(-1)
			return true
		elseif code == KEY_TAB then
			if CT.Suggestions then
				local t = CT.Suggestions[1][1] .. " "
				s:SetText(t)
				s:SetCaretPos(#t)
				CT.Suggestions = nil
			else
				completerNom(s)
			end
			timer.Simple(0, function() if IsValid(s) then s:RequestFocus() end end)
			return true
		elseif code == KEY_ESCAPE then
			CT.Fermer()
			return true
		end
	end
	CT.Entree = entree

	pan.Paint = function(s, w, h) CT.Dessiner(s, w, h) end
	pan.PaintOver = function(s, w, h) CT.DessinerSuggestions(s, w, h) end
	pan.OnMouseWheeled = function(_, delta)
		if not CT.Ouvert then return end
		local _, _, zw = CT.Zone()
		local max = math.max(0, totalLignes(zw) - math.floor(CT.HauteurZone / CT.HauteurLigne()))
		CT.Defilement = math.Clamp(CT.Defilement + delta * 3, 0, max)
		if CT.Defilement == 0 then CT.NouveauxEnBas = false end
	end
	pan.OnMousePressed = function(s, code)
		if not CT.Ouvert or code ~= MOUSE_RIGHT then return end
		local _, my = s:CursorPos()
		local msg = CT.MessageSous(my)
		if msg then CT.MenuMessage(msg) end
	end

	CT.Disposer()
	CT.Fermer(true)
end

function CT.HauteurLigne()
	surface.SetFont(UI.Police("chat"))
	local _, h = surface.GetTextSize("Ag")
	return h + UI.S(2)
end

function CT.Zone()
	local pad = UI.S(8)
	return pad, CT.HauteurOnglets + UI.S(6), CT.LargeurTotale - pad * 2, CT.HauteurZone
end

function CT.Disposer()
	local pan = CT.Panneau
	if not IsValid(pan) then return end
	local x, y, w, h, hOnglets, hMessages, hEntree = tailles()
	pan:SetPos(x, y)
	pan:SetSize(w, h)
	CT.LargeurTotale, CT.HauteurOnglets, CT.HauteurZone = w, hOnglets, hMessages
	CT.Barre:SetPos(UI.S(6), UI.S(4))
	CT.Barre:SetSize(w - UI.S(12), hOnglets - UI.S(2))
	CT.Reglages:SetSize(hOnglets, hOnglets - UI.S(4))
	CT.Reglages:SetPos(w - UI.S(12) - hOnglets, 0)
	CT.Entree:SetPos(UI.S(6), h - hEntree - UI.S(6))
	CT.Entree:SetSize(w - UI.S(12), hEntree)
end

-- Correspondance clic -> message (positions enregistrées au dessin)
local cliqueY, cliqueM, nClique = {}, {}, 0

function CT.MessageSous(my)
	local lh = CT.HauteurLigne()
	for k = 1, nClique do
		if my >= cliqueY[k] and my < cliqueY[k] + lh then return cliqueM[k] end
	end
	return nil
end

function CT.Dessiner(_, w, h)
	if ORIGINE.MenuOuvert and ORIGINE.MenuOuvert() then return end
	local ouvert = CT.Ouvert
	local zx, zy, zw, zh = CT.Zone()
	local lh = CT.HauteurLigne()
	if ouvert then
		UI.Cadre(0, 0, w, h, COL.Fond)
		UI.Rect(zx - UI.S(2), zy, zw + UI.S(4), zh, couleurZone)
	end

	local nbMax = ouvert and math.floor(zh / lh) or CC.LignesFerme
	remplirVisibles(zw, nbMax, not ouvert)

	local sx, sy = CT.Panneau:LocalToScreen(zx - UI.S(2), zy)
	local ex, ey = CT.Panneau:LocalToScreen(zx + zw + UI.S(2), zy + zh)
	render.SetScissorRect(sx, sy, ex, ey, true)
	surface.SetFont(UI.Police("chat"))
	local maintenant = CurTime()
	nClique = 0
	for k = 1, nVis do
		local ligne, msg = visL[k], visM[k]
		local y = zy + zh - k * lh
		local alpha = 255
		if not ouvert then
			alpha = math.Clamp((CC.DureeAffichage - (maintenant - msg.cree)) / 2, 0, 1) * 255
		end
		if msg.mention then
			couleurMention.r, couleurMention.g, couleurMention.b = COL.Or.r, COL.Or.g, COL.Or.b
			couleurMention.a = 45 * alpha / 255
			UI.Rect(zx - UI.S(2), y, zw + UI.S(4), lh, couleurMention)
		end
		for _, seg in ipairs(ligne) do
			if not ouvert then
				surface.SetTextColor(couleurOmbre.r, couleurOmbre.g, couleurOmbre.b, alpha * 0.8)
				surface.SetTextPos(zx + seg[3] + 1, y + 1)
				surface.DrawText(seg[1])
			end
			local c = seg[2]
			surface.SetTextColor(c.r, c.g, c.b, alpha)
			surface.SetTextPos(zx + seg[3], y)
			surface.DrawText(seg[1])
		end
		nClique = nClique + 1
		cliqueY[nClique], cliqueM[nClique] = y, msg
	end
	render.SetScissorRect(0, 0, 0, 0, false)

	if ouvert and CT.Defilement > 0 then
		local texte = CT.NouveauxEnBas and "Nouveaux messages en bas (molette)" or "Revenir en bas (molette)"
		UI.Texte(texte, "chat_petit", zx + zw, zy + zh - UI.S(2), COL.Or, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end
end

function CT.DessinerSuggestions(_, w, h)
	if not CT.Ouvert or not CT.Suggestions then return end
	local lh = UI.S(22)
	local n = #CT.Suggestions
	local bh = n * lh + UI.S(8)
	local bx, by = UI.S(6), h - UI.S(40) - bh - UI.S(4)
	UI.Cadre(bx, by, w - UI.S(12), bh, COL.Fond)
	for i, s in ipairs(CT.Suggestions) do
		local y = by + UI.S(4) + (i - 1) * lh
		UI.Texte(s[1], "chat_petit", bx + UI.S(10), y + lh / 2, i == 1 and COL.Or or COL.Texte, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.Texte(s[2], "chat_petit", bx + UI.S(120), y + lh / 2, COL.TexteSombre, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	UI.Texte("Tab : compléter", "chat_petit", w - UI.S(16), by + UI.S(4) + lh / 2, COL.TexteSombre, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

---------------------------------------------------------------------------
-- Ouvrir / fermer / envoyer
---------------------------------------------------------------------------
function CT.Ouvrir(equipe)
	if not IsValid(CT.Panneau) then CT.Construire() end
	if ORIGINE.MenuOuvert and ORIGINE.MenuOuvert() then return end
	local pan = CT.Panneau
	CT.Ouvert, CT.Equipe = true, equipe and true or false
	CT.IndexHist, CT.Defilement, CT.NouveauxEnBas = 0, 0, false
	pan:MakePopup()
	pan:SetMouseInputEnabled(true)
	pan:SetKeyboardInputEnabled(true)
	CT.Barre:SetVisible(true)
	CT.Entree:SetVisible(true)
	CT.Entree:SetText("")
	CT.Entree:RequestFocus()
	hook.Run("StartChat", CT.Equipe)
end

function CT.Fermer(silencieux)
	local pan = CT.Panneau
	if not IsValid(pan) then return end
	local etaitOuvert = CT.Ouvert
	CT.Ouvert = false
	CT.Suggestions = nil
	completion = nil
	pan:SetMouseInputEnabled(false)
	pan:SetKeyboardInputEnabled(false)
	CT.Barre:SetVisible(false)
	CT.Entree:SetVisible(false)
	CT.Entree:SetText("")
	if etaitOuvert and not silencieux then
		hook.Run("FinishChat")
		hook.Run("ChatTextChanged", "")
	end
end

function CT.Naviguer(sens)
	local h = CT.Historique
	if #h == 0 then return end
	if CT.IndexHist == 0 then CT.Brouillon = CT.Entree:GetText() end
	CT.IndexHist = math.Clamp(CT.IndexHist + sens, 0, #h)
	local texte = CT.IndexHist == 0 and (CT.Brouillon or "") or h[#h - CT.IndexHist + 1]
	CT.Entree:SetText(texte)
	CT.Entree:SetCaretPos(#texte)
	majSuggestions(texte)
end

function CT.Envoyer()
	local texte = string.Trim(CT.Entree:GetText())
	if texte ~= "" then
		if CT.Historique[#CT.Historique] ~= texte then
			table.insert(CT.Historique, texte)
			while #CT.Historique > CC.HistoriqueEnvoyes do table.remove(CT.Historique, 1) end
		end
		RunConsoleCommand(CT.Equipe and "say_team" or "say", texte)
	end
	CT.Fermer()
end

---------------------------------------------------------------------------
-- Menus contextuels
---------------------------------------------------------------------------
function CT.MenuMessage(msg)
	local m = DermaMenu()
	m:AddOption("Copier le message", function() SetClipboardText(msg.brut) end):SetIcon("icon16/page_copy.png")
	m:AddOption("Copier avec l'heure", function()
		SetClipboardText(os.date("[%H:%M:%S] ", msg.heure) .. msg.brut)
	end):SetIcon("icon16/time.png")
	local lien = msg.brut:match("https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+")
	if lien then
		m:AddOption("Ouvrir le lien", function() gui.OpenURL(lien) end):SetIcon("icon16/world_link.png")
	end
	local auteur = msg.auteur
	if IsValid(auteur) and auteur:IsPlayer() and auteur ~= LocalPlayer() then
		m:AddSpacer()
		m:AddOption("Répondre en message privé", function()
			CT.Ouvrir(false)
			local t = "/pm " .. auteur:Nick() .. " "
			CT.Entree:SetText(t)
			CT.Entree:SetCaretPos(#t)
		end):SetIcon("icon16/email.png")
		m:AddOption("Ignorer ce joueur", function()
			CT.Ignores[auteur:SteamID64()] = auteur:Nick()
			sauverIgnores()
			for i = #CT.Messages, 1, -1 do
				if CT.Messages[i].sid == auteur:SteamID64() then table.remove(CT.Messages, i) end
			end
			UI.Notifier(auteur:Nick() .. " est maintenant ignoré.", "info")
		end):SetIcon("icon16/sound_mute.png")
	end
	m:Open()
end

function CT.MenuReglages()
	local m = DermaMenu()
	local h = m:AddOption("Afficher l'heure des messages", function()
		reglerPref("horodatage", not pref("horodatage", true))
	end)
	h:SetChecked(pref("horodatage", true))
	local s = m:AddOption("Son quand on me cite", function()
		reglerPref("son", not pref("son", true))
	end)
	s:SetChecked(pref("son", true))
	m:AddSpacer()
	local n = table.Count(CT.Ignores)
	local ig = m:AddSubMenu("Joueurs ignorés (" .. n .. ")")
	for sid, nom in pairs(CT.Ignores) do
		ig:AddOption("Ne plus ignorer " .. tostring(nom), function()
			CT.Ignores[sid] = nil
			sauverIgnores()
		end)
	end
	if n == 0 then ig:AddOption("Aucun"):SetEnabled(false) end
	m:AddOption("Effacer le chat", function()
		for i = #CT.Messages, 1, -1 do CT.Messages[i] = nil end
		CT.Defilement = 0
	end):SetIcon("icon16/bin.png")
	m:Open()
end

---------------------------------------------------------------------------
-- Compatibilité : touches, fonctions chat.*, HUD sous le chat
---------------------------------------------------------------------------
hook.Add("PlayerBindPress", "origine_chat", function(_, bind, appuye)
	if not appuye then return end
	local b = string.lower(bind)
	if b:find("messagemode2", 1, true) then
		CT.Ouvrir(true)
		return true
	elseif b:find("messagemode", 1, true) then
		CT.Ouvrir(false)
		return true
	end
end)

function chat.Open(mode) CT.Ouvrir(mode ~= 1) end
function chat.Close() CT.Fermer() end

-- Le HUD (et les autres addons) se placent par rapport à ce chat
function chat.GetChatBoxPos()
	if IsValid(CT.Panneau) then return CT.Panneau:GetPos() end
	return UI.S(CC.MargeGauche), ScrH() / 2
end
function chat.GetChatBoxSize()
	if IsValid(CT.Panneau) then return CT.Panneau:GetSize() end
	return UI.S(CC.Largeur), UI.S(CC.Hauteur)
end

local prochaineDisposition = 0
hook.Add("Think", "origine_chat", function()
	if not IsValid(CT.Panneau) then return end
	CT.Panneau:SetVisible(not (ORIGINE.MenuOuvert and ORIGINE.MenuOuvert()))
	if CT.Ouvert and input.IsKeyDown(KEY_ESCAPE) then
		CT.Fermer()
		gui.HideGameUI()
	end
	if CurTime() >= prochaineDisposition then
		prochaineDisposition = CurTime() + 1
		CT.Disposer()
	end
end)

hook.Add("origine_EchelleChangee", "origine_chat", function()
	if IsValid(CT.Panneau) then CT.Disposer() end
end)

local function demarrer()
	envelopperNonParse()
	if not IsValid(CT.Panneau) then CT.Construire() end
end
hook.Add("InitPostEntity", "origine_chat", demarrer)
hook.Add("DarkRPFinishedLoading", "origine_chat", envelopperNonParse)
if IsValid(LocalPlayer()) then demarrer() end
