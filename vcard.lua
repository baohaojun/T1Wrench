#!/usr/bin/lua

local read_vcf, check_last_field
local base64

check_last_field = function (contact, field)
   if field:match("ENCODING=QUOTED%-PRINTABLE") then
      local data = contact[field]
      contact[field] = contact[field]:gsub(
         "=+(%x%x)",
         function(h) return string.char(tonumber(h,16)) end )
   end
end

read_vcf = function (vcf_path)
   local contacts = {}
   local vcf_file, _, errno = io.open(vcf_path, "rb")
   if not vcf_file then
      error(_, errno)
   end

   local contact = {}
   local last_field = ""
   local collecting_photo = false
   for line in vcf_file:lines() do
      if line == "END:VCARD\n" then
         contacts[#contacts + 1] = contact
         contact = {}
      elseif line:match("^PHOTO;") then
         collecting_photo = true;
         if not line:match("^PHOTO;ENCODING=BASE64;") then
            error ("Photo is not base64 encoded")
         end

         local photo_type = line:gsub("^PHOTO;ENCODING=BASE64;", "")
         photo_type = photo_type:gsub(";.*", "")
         contact.photo_type = photo_type;

         line = line:gsub(".*:", "")
         line = line:gsub("%s+", "")

         contact.photo_data = line
      elseif collecting_photo then
         line = line:gsub("%s+", "")
         contact.photo_data = contact.photo_data .. line
         if line == "" then
            collecting_photo = false
         end
      else
         local field, data
         line = line:gsub("%s+", "")
         if line:match(":") then
            field = line:gsub(":.*", "")
            data = line:gsub(".*:", "")
            check_last_field(contact, last_field)
            contact[field] = data
            last_field = field
         else
            contact[last_field] = contact[last_field] .. line
         end
      end
   end
   return contacts
end

if arg ~= nil then
   local arg1 = arg[1]
   arg = nil
   base64 = require'base64'
   read_vcf(arg1)
else
   base64 = require'base64'
end
