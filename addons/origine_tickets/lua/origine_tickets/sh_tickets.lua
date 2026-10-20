--[[-----------------------------------------------------------------------
	Origine du monde — tickets (partagé)
-------------------------------------------------------------------------]]

local T = ORIGINE.Tickets
local CT = ORIGINE.ConfigTickets

ORIGINE.EnregistrerPermission("origine_tickets_staff", "admin", "Tickets : traiter les demandes des joueurs (F6)")
ORIGINE.EnregistrerPermission("origine_tickets_admin", "superadmin", "Tickets : statistiques, réattribution et suppression")

function T.EstStaff(ply) return ORIGINE.APermission(ply, "origine_tickets_staff") end
function T.EstAdmin(ply) return ORIGINE.APermission(ply, "origine_tickets_admin") end

function T.CategorieValide(c)
	return isstring(c) and table.HasValue(CT.Categories, c)
end

-- Nombre de tickets en attente (reçu par le staff) : affiché dans F6 et l'en-tête du TAB
T.EnAttente = T.EnAttente or 0
