/**************************************************************************************
* Apex Class Name  :     BatchDelete
* Version            :     1.0
* Created Date       :     14/Aug/2020
* Function           :     This is Batch class to match duplicate contacts and delete them  
* Modification Log
* Developer                   Date                   Description
* ----------------------------------------------------------------------------
* Aakash                     14/Aug/2020                 Created By
*************************************************************************************/
global class BatchDelete implements Database.Batchable<sObject> {
  // Variable declaration 
  global List<Contact> contactstoCheck = new List<Contact>();
  global List<Contact> contactstoDelete = new List<Contact>();
  global List<Contact> finalcontactstoDelete = new List<Contact>();
  global Set<Id> AccountIds = new Set<Id>();

  /********************************************************************************************
 * Method   : start
 * Description: Batch implementation Method to pass data to execute method
 * ------------------------------------------------------------------------------------------
 * Date          Name                    Modification Description
 * ------------------------------------------------------------------------------------------
 * 14/Aug/2020  Aakash       Created     
 ********************************************************************************************/ 
  global Database.QueryLocator start(Database.BatchableContext bc) {
    //Query to get duplicates contacts without email address
    string query = ' SELECT Id, AccountId, Account.Name, FirstName, LastName, Primary_Contact__c, Has_NPS__c, Has_Related_Case__c, Has_Email_Retention__c, Is_Campaign_Member__c, phone FROM Contact WHERE Duplicate_Contact_On_Same_Account__c = TRUE AND Email = null ORDER BY FirstName, LastName, Primary_Contact__c ASC';
    return Database.getQueryLocator(query);
  }
/********************************************************************************************
 * Method   : execute
 * Description: logic to find contacts with only one duplicate and if there is any realted
 * record and if it is primary then leave it or delete the other one with having no related
 * record and not primary and also create log for the deleted records.
 * ------------------------------------------------------------------------------------------
 * Date          Name                    Modification Description
 * ------------------------------------------------------------------------------------------
 * 14/Aug/2020  Aakash       Created     
 ********************************************************************************************/

  global void execute(Database.BatchableContext BC, List<Contact> listofduplicateContacts) {
    if (listofduplicateContacts <> null) {
      for (Contact c : listofduplicateContacts) {
        AccountIds.add(c.AccountId);
      }
    }
    List<Duplicate_Records__c> setofLeavingRecords = new List<Duplicate_Records__c>();
    List<Duplicate_Records__c> setofToBeDeletedRecords = new List<Duplicate_Records__c>();
    for (Id loopId : AccountIds) {
      List<Contact> listofRelatedContacts = [
        SELECT Id, AccountId, Account.Name, FirstName, LastName, Primary_Contact__c, Has_NPS__c, Has_Related_Case__c, Has_Email_Retention__c, Is_Campaign_Member__c, phone, MobilePhone
        FROM Contact
        WHERE Duplicate_Contact_On_Same_Account__c = TRUE AND Email = NULL AND AccountId = :loopId
        ORDER BY LastName, FirstName, Primary_Contact__c ASC
      ];

      String lastFirstName = '';
      String lastLastName = '';
      String tempPhone = '';
      String tempmobileNumber = '';
      contactstoDelete.clear();
      for (Contact AccContact : listofRelatedContacts) {
        if (AccContact.FirstName == lastFirstName && AccContact.LastName == lastLastName && AccContact.Primary_Contact__c == true && contactstoDelete.size() > 0) {
          contactstoCheck.add(AccContact);

          for (Contact loopOverSame : contactstoCheck) {
            if (ContactstoCheck.size() == 1 && loopOverSame.Primary_Contact__c == true && contactstoDelete.size() == 1) {
              if (loopOverSame.phone == null && tempPhone <> null) {
                loopOverSame.phone = tempPhone;
                
              } else if (loopOverSame.MobilePhone == null && tempmobileNumber <> null) {
                loopOverSame.MobilePhone = tempmobileNumber;
                
              }
              //create logs and save the delete contacts in custom object called Duplicate Records     
              if (ContactstoDelete.size() > 0 && contactstoDelete[0].FirstName == loopOverSame.FirstName && contactstoDelete[0].LastName == loopOverSame.LastName) {
                Duplicate_Records__c fr = new Duplicate_Records__c();
                finalcontactstoDelete.add(contactstoDelete[0]);
                fr.Account_Id__c = contactstodelete[0].AccountId;
                fr.Account_Name__c = contactstodelete[0].Account.Name;
                fr.Contact_Id__c = contactstodelete[0].Id;
                fr.Contact_First_Name__c = contactstoDelete[0].FirstName;
                fr.Contact_Last_Name__c = contactstoDelete[0].LastName;
                fr.Contact_is_Primary__c = false;
                fr.Contact_Phone_Number__c = contactstoDelete[0].Phone;
                fr.Contact_Mobile_Number__c = contactstoDelete[0].MobilePhone;
                fr.Had_Campaign__c = contactstoDelete[0].Is_Campaign_Member__c;
                fr.Had_Email_Retention__c = contactstoDelete[0].Has_Email_Retention__c;
                fr.Had_NPS__c = contactstoDelete[0].Has_NPS__c;
                fr.Had_Related_Case__c = contactstoDelete[0].Has_Related_Case__c;
                fr.toBeDeleted__c = true;
                setofToBeDeletedRecords.add(fr);
                
              }
              //also create logs for the winner contacts to compare phone numbers and mobile number in future
              Duplicate_Records__c dr = new Duplicate_Records__c(); 
              dr.Account_Id__c = AccContact.AccountId;
              dr.Account_Name__c = AccContact.Account.Name;
              dr.Contact_Id__c = AccContact.Id;
              dr.Contact_First_Name__c = AccContact.FirstName;
              dr.Contact_Last_Name__c = AccContact.LastName;
              dr.Contact_is_Primary__c = true;
              dr.Contact_Phone_Number__c = AccContact.Phone;
              dr.Contact_Mobile_Number__c = AccContact.MobilePhone;
              dr.Had_Campaign__c = AccContact.Is_Campaign_Member__c;
              dr.Had_Email_Retention__c = AccContact.Has_Email_Retention__c;
              dr.Had_NPS__c = AccContact.Has_NPS__c;
              dr.Had_Related_Case__c = AccContact.Has_Related_Case__c;
              setofLeavingRecords.add(dr);
             
            }
          //Check if there is one duplicate contact of a winner contacts otherwise ignore
            if (ContactstoCheck.size() == 2) {
              contactstoCheck.clear();
            }
          }

          contactstoCheck.clear();
        }

        if (AccContact.Has_NPS__c == false && AccContact.Has_Related_Case__c == false && AccContact.Has_Email_Retention__c == false && AccContact.Is_Campaign_Member__c == false) {
          contactstoDelete.add(AccContact);
        }

        if (contactstoDelete.size() > 1) {
          contactstoDelete.clear();
        }

        lastFirstName = AccContact.FirstName;
        lastLastName = AccContact.LastName;
        tempPhone = AccContact.Phone;
        tempmobileNumber = AccContact.MobilePhone;
      }
    }
    Database.insert(setofToBeDeletedRecords, false);
    Database.insert(setofLeavingRecords, false);
    delete finalcontactstoDelete;
  }
  /********************************************************************************************
 * Method   : finish
 * Description: Delete Duplicate Contacts
 * ------------------------------------------------------------------------------------------
 * Date          Name                    Modification Description
 * ------------------------------------------------------------------------------------------
 * 14/Aug/2018  Aakash       Created     
 ********************************************************************************************/
  global void finish(Database.BatchableContext BC) {
  }
}
