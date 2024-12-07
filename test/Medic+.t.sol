// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test, console, console2 } from "../lib/forge-std/src/Test.sol";
import { MedicPlusManager } from "../src/Medic+.sol";

contract MedicPlusManagerTest is Test {
    // struct CaseFolder{
    //     uint256 caseId;
    //     uint256 issueDate;//Indica la fecha de alta
    //     string cid;// Identificador único del archivo en IPFS
    //     string name;
    //     string description;
    //     address patient;
    //     bool exists;
    // }
//  struct Permission{//REVISAR
//         bool fullAccess;// Acceso total a todos los documentos
//         bool temporaryAccess;//Acceso temporal
//         uint256 expiration;//Fecha de expiración del permiso temporal(en timestamp)
//         // mapping(Permission => SpecificPermission) specificPermissions;//Permisos especificos para ciertos casos
//         // uint256 caseId; //ID del caso específico al que se aplica el permiso. Es 0 si no hay case especifico
//     }    

    struct FullPermission {
        bool fullAccess; // Acceso total a todos los documentos
        bool temporaryAccess; // Acceso temporal
        uint256 expiration; // Fecha de expiración del permiso temporal (en timestamp)
    }
    struct SpecificPermission {
            // uint256 caseId; // ID del caso específico
            bool hasAccess; // Indica si el permiso específico está otorgado
            uint256 expiration; // Fecha de expiración del permiso específico (en timestamp). Si no la tiene, debe ser 0
        }

    event CaseUploaded(uint256 caseId, string cid, string name, address patient, uint256 issueDate);
    event FullPermissionGranted(address patient, address recipient);
    event CasePermissionGranted(address patient, address recipient, uint256 caseId);
    event FullPermissionRevoqued(address patient, address recipient);
    event CasePermissionRevoqued(address patient, address recipient, uint256 caseId);
    event CaseEdited(uint256 caseId, uint256 editDate);

    MedicPlusManager medicplus;
    address alice;//doctor
    address bob;//paciente
    address carol;//otropaciente

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        medicplus = new MedicPlusManager();
        medicplus.transferOwnership(alice);
        startHoax(alice);
    }
    function testUploadCase() public {
        uint256 issueDate = block.timestamp;
        // Crear un caso
        vm.expectEmit();
        emit CaseUploaded(1, "example-cid", "Case1", bob, issueDate);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);

        // CaseFolder memory caseFolder = CaseFolder({
        //     caseId: 1,
        //     issueDate: block.timestamp,
        //     cid: "example-cid",
        //     name: "Case1",
        //     description: "Some description",
        //     patient: bob,
        //     exists: true    
        // });
        // medicplus.uploadCase(caseFolder.cid, caseFolder.name, caseFolder.description, caseFolder.patient, caseFolder.issueDate);
       
        MedicPlusManager.CaseFolder memory case1 = medicplus.getCase(1);
        assertEq(case1.cids[0], "example-cid", "El CID no coincide");
        assertEq(case1.name, "Case1", "El nombre no coincide");
        assertEq(case1.description, "Some description", "La descripcion no coincide");
        assertEq(case1.patient, bob, "El paciente no coincide");
        assertEq(case1.issueDate, issueDate, "La fecha no coincide");
        assertTrue(case1.exists, "El caso deberia existir");
    }
      function testUploadCaseFail() public {
        uint256 issueDate = block.timestamp;
        vm.expectRevert("Invalid name");
        medicplus.uploadCase("example-cid", "", "Some description", bob, issueDate);
        vm.expectRevert("Invalid description");
        // vm.stopPrank();
        // vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "", bob, issueDate);
        // vm.stopPrank();
        // vm.startPrank(carol);
        vm.expectRevert("Invalid patient address");
        medicplus.uploadCase("example-cid", "Case1", "Some description", address(0), issueDate);
      }
      function testEditCase() public {
         uint256 issueDate = block.timestamp;
        // Crear el caso  1
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        uint256 editDate = block.timestamp;
        // Editar el caso 1
        vm.expectEmit();
        emit CaseEdited(1, editDate);
        medicplus.editCase(1, "example-cid-2", "", "");
        MedicPlusManager.CaseFolder memory case1 = medicplus.getCase(1);
        assertEq(case1.cids[1], "example-cid-2", "El CID no coincide");
        medicplus.editCase(1, "", "Case2", "");
        MedicPlusManager.CaseFolder memory case1_1 = medicplus.getCase(1);
        assertEq(case1_1.name, "Case2", "El nombre no coincide");
        medicplus.editCase(1, "", "", "Another description");
        MedicPlusManager.CaseFolder memory case1_2 = medicplus.getCase(1);
        assertEq(case1_2.description, "Another description", "El CID no coincide");
        assertEq(case1_2.issueDate, editDate, "El CID no coincide");


        // assertEq(case1.name, "Case1", "El nombre no coincide");
        // assertEq(case1.description, "Some description", "La descripcion no coincide");
        // assertEq(case1.patient, bob, "El paciente no coincide");
        // assertEq(case1.issueDate, issueDate, "La fecha no coincide");
        // assertTrue(case1.exists, "El caso deberia existir");
      }
      function testGrantFullAccess() public {
        vm.stopPrank();
        vm.startPrank(bob);
        // Permisos totales para el paciente bob
        // medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);

        vm.expectEmit();    
        emit FullPermissionGranted(bob, alice); 
        medicplus.grantFullPermission(alice, 0);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 0), true, "El permiso no se ha otorgado");
        // Persisos totales temporales para el paciente carol
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
        vm.expectEmit();
        emit FullPermissionGranted(bob, carol);
        medicplus.grantFullPermission(carol, expiration);
        assertEq(medicplus.isTemporaryPermissionActive(carol, bob, 0), true, "El permiso temporal no se ha otorgado");
      }
      function testGrantFullAccessFail() public {
        vm.stopPrank();
        vm.startPrank(bob);
        // Permisos totales para el paciente bob
        // medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        vm.expectRevert(abi.encodeWithSignature("NoValidAddress()"));
        medicplus.grantFullPermission(address(0), 0);
        // Persisos totales temporales para el paciente carol
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
      }
      function testRevokeFullAccess() public {
        vm.stopPrank();
        vm.startPrank(bob);
        // Permisos totales para el paciente bob
        vm.expectEmit();    
        emit FullPermissionGranted(bob, alice); 
        medicplus.grantFullPermission(alice, 0);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 0), true, "El permiso no se ha otorgado");
        // Permisos totales temporales para el paciente carol
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
        vm.expectEmit();
        emit FullPermissionGranted(bob, carol);
        medicplus.grantFullPermission(carol, expiration);
        assertEq(medicplus.isTemporaryPermissionActive(carol, bob, 0), true, "El permiso temporal no se ha otorgado");
        // Revocar los permisos
        vm.expectEmit();
        emit FullPermissionRevoqued(bob, alice);
        medicplus.revokeFullPermission(alice);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 0), false, "El permiso no se ha revocado");
        vm.expectEmit();
        emit FullPermissionRevoqued(bob, carol);
        medicplus.revokeFullPermission(carol);
        assertEq(medicplus.isTemporaryPermissionActive(carol, bob, 0), false, "El permiso temporal no se ha revocado");
      }
    function testGrantCasePermission() public{
        uint256 issueDate = block.timestamp;
        vm.stopPrank();
        vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        vm.expectEmit();
        emit CasePermissionGranted(bob, alice, 1);
        medicplus.grantCasePermission(alice, 1, 0);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 1), true, "El permiso no se ha otorgado");
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
        medicplus.grantCasePermission(alice, 1, expiration);
        assertEq(medicplus.isTemporaryPermissionActive(alice, bob, 1), true, "El permiso no se ha otorgado");
    
    }
    function testRevokeCasePermission() public{
        uint256 issueDate = block.timestamp;
        vm.stopPrank();
        vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        vm.expectEmit();
        emit CasePermissionGranted(bob, alice, 1);
        medicplus.grantCasePermission(alice, 1, 0);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 1), true, "El permiso no se ha otorgado");
        vm.expectEmit();
        emit CasePermissionRevoqued(bob, alice, 1);
        medicplus.revokeCasePermission(alice, 1);
        assertEq(medicplus.isFullPermissionActive(alice, bob, 1), false, "El permiso no se ha revocado");
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
        medicplus.grantCasePermission(alice, 1, expiration);
        assertEq(medicplus.isTemporaryPermissionActive(alice, bob,1), true, "El permiso no se ha otorgado");
        vm.expectEmit();
        emit CasePermissionRevoqued(bob, alice, 1);
        medicplus.revokeCasePermission(alice, 1);
        assertEq(medicplus.isTemporaryPermissionActive(alice, bob, 1), false, "El permiso temporal no se ha revocado");
    }
    function testHassAccess() public{
        uint256 issueDate = block.timestamp;
        vm.stopPrank();
        vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        medicplus.grantCasePermission(alice, 1, 0);
        assertEq(medicplus.hasAccess(bob, alice, 1), true, "El paciente no tiene acceso al caso");
        uint256 expiration = block.timestamp + 3600 * 24;//Permisos temporales de 1 dia
        medicplus.grantCasePermission(carol, 1, expiration);
        assertEq(medicplus.hasAccess(bob, carol, 1), true, "El paciente no tiene acceso al caso");
    }
    function testGetAllCases() public{
        uint256 issueDate = block.timestamp;
        vm.stopPrank();
        vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        medicplus.uploadCase("example-cid", "Case2", "Some description", bob, issueDate);
        medicplus.uploadCase("example-cid", "Case3", "Some description", bob, issueDate);
        assertEq(medicplus.getAllCases(bob).length, 3, "El paciente no tiene acceso al caso");
        for(uint256 i = 10; i <= 3; i++){
            uint256 caseId = medicplus.getAllCases(bob)[i].caseId;
            uint256 id = i;
            assertEq(caseId, id, "Los id de los casos no coinciden");
            string memory cid = medicplus.getAllCases(bob)[i].cids[0];
            assertEq(cid, "example-cid", "Los cid de los casos no coinciden");
        }
    }
    function testGetCase() public{
        uint256 issueDate = block.timestamp;
        vm.stopPrank();
        vm.startPrank(bob);
        medicplus.uploadCase("example-cid", "Case1", "Some description", bob, issueDate);
        assertEq(medicplus.getCase(1).caseId, 1, "El id del caso no coincide");
        assertEq(medicplus.getCase(1).cids[0], "example-cid", "El cid del caso no coincide");
    }
}