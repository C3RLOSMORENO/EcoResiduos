const express = require('express');
const router = express.Router();
const materialController = require('../controllers/MaterialController');

router.get('/', materialController.renderMaterialesPage);
router.post('/', materialController.handleCreateMaterial);
router.post('/delete/:id', materialController.handleDeleteMaterial);

module.exports = router;