module("luci.controller.rakitan", package.seeall)
function index()
entry({"admin","modem","rakitan"}, template("rakitan"), _("Rakitan Manager"), 7).leaf=true
end
