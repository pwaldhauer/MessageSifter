//
//  main.swift
//  MessageSifter
//
//  Created by Philipp Waldhauer on 03.02.24.
//

import Foundation
import SQLite3

extension Data {
    static func fromHexEncodedString(_ string: String) -> Data? {
        let chars = Array(string.utf8)
        var i = 0

        var data = Data(capacity: string.count / 2)
        var byteChars: [CChar] = [0, 0, 0]
        var wholeByte: UInt8

        while i < string.count {
            byteChars[0] = CChar(chars[i])
            i += 1
            byteChars[1] = CChar(chars[i])
            i += 1
            wholeByte = UInt8(strtoul(byteChars, nil, 16))
            data.append(&wholeByte, count: 1)
        }

        return data
    }

    static func fromHexEncodedFile(_ filePath: String) -> Data? {
        guard let fileContents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }

        return fromHexEncodedString(fileContents)
    }
}

struct Message {
    let date: Date
    let text: String
    let text2: String
}

func executeSelectQuery(fileURL: String, limit: Int) -> Void {
    var db: OpaquePointer?
    
    let openResult = sqlite3_open(fileURL, &db);

    // Versuch, die SQLite-Datenbank zu öffnen
    if  openResult != SQLITE_OK {
        print("Fehler beim Öffnen der Datenbank.\(openResult) ")
        return
    }

    // SQL-Abfrage
    let query = "SELECT HEX(attributedBody) as body, text, datetime(date/1000000000 + strftime('%s','2001-01-01'), 'unixepoch','localtime') as dateString from message where handle_id = 1 order by date desc limit \(limit);"

    var statement: OpaquePointer?

    // Vorbereitung und Ausführung der SQL-Abfrage
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                var text = ""
                var text2 = ""
                var date = Date.now
                
                
                // Extrahieren der Daten aus der Spalte "attributedString"
                if let data = sqlite3_column_blob(statement, 0) {
                    let dataSize = sqlite3_column_bytes(statement, 0)
                    let nsData = Data(bytes: data, count: Int(dataSize))
            
                    if let decodedHexString = String(data: nsData, encoding: .utf8) {
                        if let hexAsData = Data.fromHexEncodedString(decodedHexString) {
                            do {
                                let attri = try NSUnarchiver(forReadingWith: hexAsData)?.decodeTopLevelObject()
                                if let pups = attri {
                                    if let wup = pups as? NSAttributedString {
                                        text = wup.string
                                    }
                                }
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
                
                
                if let texxt = sqlite3_column_text(statement, 1) {
                    text2 = String(cString: texxt)
                }
                       
                
                if let timestamp = sqlite3_column_text(statement, 2) {
                    date = dateFormatter.date(from: String(cString: timestamp)) ?? Date.now
                }
                                    
                let message = Message(date: date, text: text, text2: text2)
                print("\(message.date)|\(message.text.replacingOccurrences(of: "\n", with: " "))|\(message.text2.replacingOccurrences(of: "\n", with: " "))")
            }
        } else {
            print("Fehler beim Vorbereiten der Abfrage.")
        }
    
    // Schließen der Datenbank und Freigabe von Ressourcen
    sqlite3_finalize(statement)
    sqlite3_close(db)
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()


let arguments = CommandLine.arguments

var fileURL = arguments.count > 1 ? arguments[1] : "/Users/pwaldhauer/test.db"
var limit = arguments.count > 2 ? Int(arguments[2])! : 100;

print(arguments)

executeSelectQuery(fileURL: fileURL, limit: limit)
