--[[-----------------------------------------------------------------------
	Origine du monde — réception client (notifications, annonces)
-------------------------------------------------------------------------]]

net.Receive("origine_notif", function()
	local texte = net.ReadString()
	local typ = net.ReadString()
	ORIGINE.UI.Notifier(texte, typ)
end)

-- Annonce de tirage dans la couleur du palier
net.Receive("origine_annonce", function()
	local couleur = net.ReadColor()
	local texte = net.ReadString()
	chat.AddText(ORIGINE.UI.C.Or, "[Origine] ", couleur, texte)
end)

-- Le Lua client est chargé : le serveur peut envoyer le menu
local function pret()
	if ORIGINE.ClientPret then return end
	ORIGINE.ClientPret = true
	net.Start("origine_pret")
	net.SendToServer()
end
hook.Add("InitPostEntity", "origine_pret", pret)
if IsValid(LocalPlayer()) then timer.Simple(1, pret) end
