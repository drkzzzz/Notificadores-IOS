# -*- coding: utf-8 -*-
filepath = r'C:\laragon\www\reportsat2\resources\views\admin\app\sgtm\cobranza\index.blade.php'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = '// ===== CARTERA NOTIFICACIONES ====='
end_marker = '</script>'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker, start_idx + 10) + len(end_marker)

if start_idx == -1 or end_idx == -1:
    print(f'ERROR: start={start_idx}, end={end_idx}')
    exit(1)

print(f'Found section from {start_idx} to {end_idx}')

new_js = '''    // ===== CARTERA NOTIFICACIONES =====
    var cnFiscalizadores = [];
    var cnRowsBloques = [];
    var cnRowsDetalle = [];
    var cnAsignacionesPendientes = [];
    var cnAsignados = {};

    function cnCargarFechas() {
      $.getJSON('/admin/sgtm-cobranzas/oprd/listas', function(resp) {
        if (!resp.status) return;
        var s = $('#cn_fecha').empty();
        s.append('<option value="">-- Seleccione --</option>');
        var opMap = {}, rdMap = {};
        $.each(resp.op, function(i, r) { opMap[r.fecha] = r.total; });
        $.each(resp.rd, function(i, r) { rdMap[r.fecha] = r.total; });
        var fechas = [];
        $.each(opMap, function(k) { fechas.push(k); });
        $.each(rdMap, function(k) { if (fechas.indexOf(k) === -1) fechas.push(k); });
        fechas.sort(function(a, b) { return b.localeCompare(a); });
        $.each(fechas, function(i, f) {
          s.append('<option value="' + f + '">' + f + ' &mdash; OP: ' + (opMap[f] || 0) + ' | RD: ' + (rdMap[f] || 0) + '</option>');
        });
      }).fail(function() { console.error('Error cargando fechas CN'); });
    }

    function cnBuscar() {
      var fecha = $('#cn_fecha').val();
      if (!fecha) { alert('Seleccione una fecha.'); return; }
      var identificador = parseInt(fecha.replace(/-/g, ''), 10);
      $('#cn_identificador').val(identificador);
      $('#cn_bloque_seleccionado').val('');
      cnCargarBloques(fecha);
    }

    function cnCargarBloques(fecha) {
      if (!fecha) return;
      var btn = $('#cn_btn_buscar');
      btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i>');
      var identificador = parseInt(fecha.replace(/-/g, ''), 10);
      $('#cn_identificador').val(identificador);

      $.getJSON('/admin/sgtm-cobranzas/oprd/bloques', { fecha: fecha }, function(resp) {
        if (!resp.status) { alert('Error al cargar bloques.'); return; }
        cnRowsBloques = resp.items || [];
        cnRenderBloques(resp.fecha);
        $('#cn_detalle_block').hide();
        cnActualizarResumenAsignacion();
      }).fail(function() {
        alert('Error al cargar bloques.');
      }).always(function() {
        btn.prop('disabled', false).html('<i class="fa fa-search"></i> BUSCAR');
      });
    }

    function cnRenderBloques(fecha) {
      var tb = $('#cn_tbody_bloques').empty();
      if (!cnRowsBloques.length) {
        tb.append('<tr><td colspan="5" class="text-center" style="color:#999">No hay bloques para esta fecha.</td></tr>');
        $('#cn_info_total').html('');
        return;
      }
      $.each(cnRowsBloques, function(i, b) {
        var total = (b.op_count || 0) + (b.rd_count || 0);
        tb.append(
          '<tr style="cursor:pointer" onclick="cnSeleccionarBloque(' + b.bloque + ')" id="cn_fila_bloque_' + b.bloque + '">' +
            '<td>' + (i + 1) + '</td>' +
            '<td><strong>' + b.bloque + '</strong></td>' +
            '<td class="text-center">' + (b.op_count || 0) + '</td>' +
            '<td class="text-center">' + (b.rd_count || 0) + '</td>' +
            '<td class="text-center"><strong>' + total + '</strong></td>' +
          '</tr>'
        );
      });
      var totalOp = 0, totalRd = 0;
      $.each(cnRowsBloques, function(i, b) {
        totalOp += (b.op_count || 0);
        totalRd += (b.rd_count || 0);
      });
      $('#cn_info_total').html(
        '<strong>Fecha:</strong> ' + fecha + ' &mdash; <strong>Total OP:</strong> ' + totalOp + ' | <strong>Total RD:</strong> ' + totalRd + ' &mdash; <strong>Total bloques:</strong> ' + cnRowsBloques.length
      );
    }

    function cnSeleccionarBloque(bloque) {
      $('#cn_bloque_seleccionado').val(bloque);
      $('#cn_tbody_bloques tr').css('background', '');
      $('#cn_fila_bloque_' + bloque).css('background', '#fff3e0');
      cnCargarDetalleBloque(bloque);
    }

    function cnCargarDetalleBloque(bloque) {
      var fecha = $('#cn_fecha').val();
      if (!fecha || !bloque) return;
      var btn = $('#cn_btn_buscar');
      btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i>');

      $.getJSON('/admin/sgtm-cobranzas/oprd/bloque-detalle', { fecha: fecha, bloque: bloque }, function(resp) {
        if (!resp.status) { alert('Error al cargar detalle del bloque.'); return; }
        cnRowsDetalle = resp.items || [];
        cnRenderDetalle(resp.bloque, resp.items);
      }).fail(function() {
        alert('Error al cargar detalle del bloque.');
      }).always(function() {
        btn.prop('disabled', false).html('<i class="fa fa-search"></i> BUSCAR');
      });
    }

    function cnRenderDetalle(bloque, items) {
      $('#cn_detalle_block').show();
      $('#cn_detalle_bloque_num').html('#' + bloque);
      var totalContribuyentes = items.length;
      var nOp = items.filter(function(d) { return d.tiene_op; }).length;
      var nRd = items.filter(function(d) { return d.tiene_rd; }).length;
      $('#cn_detalle_counters').html('(' + totalContribuyentes + ' contribuyente(s) | OP: ' + nOp + ' | RD: ' + nRd + ')');

      var tb = $('#cn_tbody_detalle').empty();
      if (!items.length) {
        tb.append('<tr><td colspan="6" class="text-center" style="color:#999">Sin contribuyentes en este bloque.</td></tr>');
        return;
      }
      $.each(items, function(i, d) {
        var key = 'D_' + d.cod;
        var asignado = cnAsignados[key] !== undefined;
        var cls = asignado ? 'style="background:#e8f5e9"' : '';
        tb.append(
          '<tr ' + cls + '>' +
            '<td><input type="checkbox" class="cn_chk_detalle" value="' + d.cod + '" data-cod="' + d.cod + '" data-nombre="' + (d.nombre || '').replace(/"/g, '&quot;') + '" data-op="' + (d.op_correlativo || '') + '" data-rd="' + (d.rd_correlativo || '') + '" data-tipo="OP"' + (asignado ? ' disabled' : '') + '></td>' +
            '<td>' + d.cod + '</td>' +
            '<td>' + (d.nombre || '-') + '</td>' +
            '<td class="text-center">' + (d.op_correlativo || '-') + '</td>' +
            '<td class="text-center">' + (d.rd_correlativo || '-') + '</td>' +
            '<td class="text-center">' + (asignado ? '<span class="label label-success">SI</span>' : '<span class="label label-default">NO</span>') + '</td>' +
          '</tr>'
        );
      });
    }

    function cnCargarFiscalizadores() {
      $.getJSON('/admin/sgtm-cobranzas/cartera-notificaciones/fiscalizadores', function(resp) {
        if (resp.status) {
          cnFiscalizadores = resp.data;
          var tb = $('#cn_tbody_fiscalizadores').empty();
          $.each(resp.data, function(i, r) {
            tb.append(cnFilaNotificador(r));
          });
          cnBindingNotificadorBuscar();
          cnActualizarContadoresNotificadores(resp.total);
          cnActualizarResumenAsignacion();
        }
      }).fail(function() { console.error('Error cargando notificadores'); });
    }

    function cnFilaNotificador(r) {
      var estadoTxt = r.estado === 'A'
        ? '<span class="label label-success">ACTIVO</span>'
        : '<span class="label label-default">INACTIVO</span>';
      var fecha = r.fecha_registro || '-';
      return '<tr>' +
        '<td><input type="checkbox" class="cn_chk_notif" value="' + r.id + '" data-nombre="' + (r.nombre || '').replace(/"/g, '&quot;') + '" onclick="cnActualizarResumenAsignacion()"></td>' +
        '<td>' + r.id + '</td>' +
        '<td>' + (r.nombre || '-') + '</td>' +
        '<td>' + fecha + '</td>' +
        '<td>' + estadoTxt + '</td>' +
      '</tr>';
    }

    function cnBindingNotificadorBuscar() {
      $('#cn_notif_buscar').off('keyup').on('keyup', function() {
        var q = $.trim($(this).val()).toLowerCase();
        cnActualizarContadoresNotificadores();
        cnActualizarResumenAsignacion();
        $('.cn_chk_notif').each(function() {
          var row = $(this).closest('tr');
          var nombre = ($(this).data('nombre') || '').toLowerCase();
          var id = $(this).val();
          var show = q === '' || nombre.indexOf(q) !== -1 || String(id).indexOf(q) !== -1;
          row.toggle(show);
        });
      });
    }

    function cnActualizarContadoresNotificadores(total) {
      if (!total) total = cnFiscalizadores.length;
      var sel = $('.cn_chk_notif:checked').length;
      $('#cn_notif_counters').html('(' + total + ' registros &middot; ' + sel + ' seleccionado(s))');
    }

    function cnToggleNotificadores(master) {
      $('.cn_chk_notif').prop('checked', master.checked);
      cnActualizarContadoresNotificadores();
      cnActualizarResumenAsignacion();
    }

    function cnGetNotificadoresSeleccionados() {
      var seleccionados = [];
      $('.cn_chk_notif:checked').each(function() {
        seleccionados.push({ id: parseInt($(this).val(), 10), nombre: $(this).data('nombre') });
      });
      return seleccionados;
    }

    function cnContarContribuyentesPendientes() {
      var total = $('.cn_chk_detalle:not(:disabled)').length;
      return total;
    }

    function cnActualizarResumenAsignacion() {
      cnActualizarContadoresNotificadores();
      var nNotificadores = $('.cn_chk_notif:checked').length;
      var nContribuyentes = cnContarContribuyentesPendientes();
      if (nNotificadores > 0 && nContribuyentes > 0) {
        var porNotificador = Math.floor(nContribuyentes / nNotificadores);
        var sobrante = nContribuyentes % nNotificadores;
        var html = '<strong>Resumen de distribucion:</strong><br>' +
          'Tenemos <strong>' + nContribuyentes.toLocaleString('es-PE') + '</strong> contribuyente(s) que seran distribuidos entre <strong>' + nNotificadores + '</strong> notificador(es).<br>' +
          'Cada notificador recibira ~<strong>' + porNotificador.toLocaleString('es-PE') + '</strong> contribuyente(s)';
        if (sobrante > 0) html += ' (+<strong>' + sobrante + '</strong> sobrante(s))';
        html += '.';
        $('#cn_resumen_asignacion').html(html).show();
      } else if (nContribuyentes > 0) {
        $('#cn_resumen_asignacion').html(
          '<strong>Resumen de distribucion:</strong><br>Tenemos <strong>' + nContribuyentes.toLocaleString('es-PE') +
          '</strong> contribuyente(s). Seleccione al menos un <strong>notificador</strong> para calcular la distribucion.'
        ).show();
      } else {
        $('#cn_resumen_asignacion').hide();
      }
    }

    function cnToggleAllCheckboxes(master, selector) {
      $(selector + ':not(:disabled)').prop('checked', master.checked);
    }

    function cnAsignacionAutomatica() {
      var identificador = $('#cn_identificador').val();
      var bloque = $('#cn_bloque_seleccionado').val();
      if (!identificador || !bloque) { alert('Seleccione un bloque primero.'); return; }

      var seleccionados = cnGetNotificadoresSeleccionados();
      if (!seleccionados.length) { alert('Seleccione al menos un notificador.'); return; }

      var pendientes = [];
      $('.cn_chk_detalle:not(:disabled):checked').each(function() {
        pendientes.push({
          tipo: 'OP',
          CodContribuyente: $(this).val(),
          Nombre: $(this).data('nombre'),
          Correlativo: $(this).data('op') || $(this).data('rd'),
        });
      });

      if (!pendientes.length) {
        $('.cn_chk_detalle:not(:disabled):not(:checked)').each(function() {
          pendientes.push({
            tipo: 'OP',
            CodContribuyente: $(this).val(),
            Nombre: $(this).data('nombre'),
            Correlativo: $(this).data('op') || $(this).data('rd'),
          });
        });
      }

      if (!pendientes.length) { alert('No hay contribuyentes para asignar.'); return; }

      var ids = $.map(seleccionados, function(f) { return f.id; });
      cnAsignacionesPendientes = [];
      $.each(pendientes, function(i, item) {
        var idx = i % ids.length;
        cnAsignacionesPendientes.push({
          tipo: item.tipo,
          CodContribuyente: item.CodContribuyente,
          Nombre: item.Nombre,
          Correlativo: item.Correlativo,
          codNotificador: ids[idx],
        });
      });

      cnActualizarPendientes();
      var porNotif = Math.floor(pendientes.length / ids.length);
      var sobrante = pendientes.length % ids.length;
      var txtDetalle = porNotif + ' contribuyente(s) por notificador';
      if (sobrante > 0) txtDetalle += ' (+' + sobrante + ' sobrante(s))';
      $('#cn_resultado').html(
        '<div class="alert alert-info" style="margin:0; padding:8px 12px"><strong>Asignacion automatica preparada.</strong> ' +
        pendientes.length + ' contribuyente(s) distribuido(s) entre ' + ids.length + ' notificador(es). ' +
        txtDetalle + '. Presione GRABAR para guardar.</div>'
      ).show();
    }

    function cnAsignacionManual() {
      var identificador = $('#cn_identificador').val();
      var bloque = $('#cn_bloque_seleccionado').val();
      if (!identificador || !bloque) { alert('Seleccione un bloque primero.'); return; }

      var seleccionados = cnGetNotificadoresSeleccionados();
      if (!seleccionados.length) { alert('Seleccione al menos un notificador.'); return; }

      var contribuyentes = [];
      $('.cn_chk_detalle:not(:disabled):checked').each(function() {
        contribuyentes.push({
          tipo: 'OP',
          CodContribuyente: $(this).val(),
          Nombre: $(this).data('nombre'),
          Correlativo: $(this).data('op') || $(this).data('rd'),
        });
      });

      if (!contribuyentes.length) { alert('Seleccione al menos un contribuyente del detalle del bloque.'); return; }

      $.each(contribuyentes, function(i, item) {
        var idx = i % seleccionados.length;
        cnAsignacionesPendientes.push({
          tipo: item.tipo,
          CodContribuyente: item.CodContribuyente,
          Nombre: item.Nombre,
          Correlativo: item.Correlativo,
          codNotificador: seleccionados[idx].id,
        });
      });

      cnActualizarPendientes();
      var noms = $.map(seleccionados, function(f) { return f.nombre; }).join(', ');
      $('#cn_resultado').html(
        '<div class="alert alert-info" style="margin:0; padding:8px 12px"><strong>Asignacion manual preparada.</strong> ' +
        contribuyentes.length + ' contribuyente(s) asignado(s) a: <strong>' + noms + '</strong>. Presione GRABAR para guardar.</div>'
      ).show();
    }

    function cnActualizarPendientes() {
      $('#cn_pendientes_info').html(cnAsignacionesPendientes.length + ' pendiente(s)');
    }

    function cnGrabar() {
      var identificador = $('#cn_identificador').val();
      if (!identificador) { alert('Primero seleccione un bloque.'); return; }
      if (!cnAsignacionesPendientes.length) { alert('No hay asignaciones pendientes.'); return; }

      var btn = $('#cn_btn_grabar');
      btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> Guardando...');

      $.ajax({
        url: '/admin/sgtm-cobranzas/cartera-notificaciones/guardar',
        type: 'POST',
        data: {
          _token: $('meta[name="csrf-token"]').attr('content'),
          identificador: parseInt(identificador, 10),
          asignaciones: cnAsignacionesPendientes
        },
        dataType: 'json',
        success: function(resp) {
          if (resp.status) {
            $('#cn_resultado').html(
              '<div class="alert alert-success" style="margin:0; padding:8px 12px"><strong>Exito.</strong> ' + resp.message + '</div>'
            ).show();
            cnAsignacionesPendientes = [];
            cnActualizarPendientes();
            var fecha = $('#cn_fecha').val();
            cnCargarBloques(fecha);
          } else {
            $('#cn_resultado').html(
              '<div class="alert alert-danger" style="margin:0; padding:8px 12px"><strong>Error:</strong> ' + (resp.message || 'No se pudo guardar.') + '</div>'
            ).show();
          }
        },
        error: function(xhr) {
          var msg = 'Error del servidor.';
          if (xhr.responseJSON && xhr.responseJSON.message) msg = xhr.responseJSON.message;
          $('#cn_resultado').html(
            '<div class="alert alert-danger" style="margin:0; padding:8px 12px"><strong>Error:</strong> ' + msg + '</div>'
          ).show();
        },
        complete: function() {
          btn.prop('disabled', false).html('<i class="fa fa-floppy-o"></i> GRABAR');
        }
      });
    }

    $(document).ready(function() {
      cnCargarFechas();
      cnCargarFiscalizadores();
    });

'''

new_content = content[:start_idx] + new_js + content[end_idx:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)

print('JS section replaced successfully')
print(f'New file size: {len(new_content)} chars')
